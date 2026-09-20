import 'dart:async';
import 'package:file_picker/file_picker.dart';
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


class NurseHomeScreen extends StatefulWidget {
  final VoidCallback onLogout;

  const NurseHomeScreen({super.key, required this.onLogout});

  @override
  State<NurseHomeScreen> createState() => _NurseHomeScreenState();
}

class _NurseHomeScreenState extends State<NurseHomeScreen> {
  int _currentTab = 0;
  final api = ApiService();

  List<dynamic> patients = [];
  List<dynamic> vitalSigns = [];
  List<dynamic> beds = [];
  List<dynamic> alerts = [];
  List<dynamic> doctors = [];
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
    final results = await Future.wait([
      api.getPatients(),
      api.getVitalSigns(),
      api.getBeds(),
      api.getAlerts(),
      api.getDoctors(),
    ]);
    if (mounted) {
      final cleanVitals = results[1].where((v) {
        final id = v['_id']?.toString() ?? v['id']?.toString();
        return id != null && !_deletedVitalIds.contains(id);
      }).toList();
      setState(() {
        patients = results[0];
        vitalSigns = cleanVitals;
        beds = results[2];
        alerts = results[3];
        doctors = results[4];
        isLoading = false;
      });
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
      drawer: AppDrawer(
        onSelectTab: (idx) => setState(() => _currentTab = idx),
        onOpenProfile: _openProfile,
        onLogout: widget.onLogout,
      ),
      appBar: AppBar(
        backgroundColor: AppTheme.getRoleColor('NURSE'),
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
                errorBuilder: (context, error, stackTrace) => const Icon(CupertinoIcons.heart_fill, color: AppTheme.primary, size: 20),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Soins Infirmiers',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    fullName.isNotEmpty ? fullName : 'Infirmier(ère)',
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

          // Bouton d'alertes avec compteur
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                tooltip: 'Alertes médicales',
                onPressed: _showAlertsModal,
              ),
              if (unreadAlertCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
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
                role: 'NURSE',
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
                _buildOverviewTab(),
                _buildPatientsTab(),
                _buildVitalsTab(),
                _buildBedsTab(),
              ],
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTab,
        onDestinationSelected: (idx) => setState(() => _currentTab = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_shared_outlined),
            selectedIcon: Icon(Icons.folder_shared),
            label: 'Patients',
          ),
          NavigationDestination(
            icon: Icon(Icons.monitor_heart_outlined),
            selectedIcon: Icon(Icons.monitor_heart),
            label: 'Constantes',
          ),
          NavigationDestination(
            icon: Icon(Icons.bed_outlined),
            selectedIcon: Icon(Icons.bed),
            label: 'Lits',
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Bannière Infirmière
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
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
                        'Unité d\'Hospitalisation & Soins',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Poste Soignant Actif',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _badgeStat('${patients.length} Patients', onTap: () => setState(() => _currentTab = 1)),
                          _badgeStat('${vitalSigns.length} Constantes', onTap: () => setState(() => _currentTab = 2)),
                          _badgeStat('${beds.length} Lits', onTap: () => setState(() => _currentTab = 3)),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 60,
                  height: 60,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/logo-polyclinique-arij.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.healing, size: 36, color: AppTheme.primary),
                  ),
                ),
              ],
            ),
          ),

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

          // Dernières constantes
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Dernières Constantes Prises',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              TextButton(
                onPressed: () => setState(() => _currentTab = 2),
                child: const Text('Voir tout'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (vitalSigns.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Aucune constante saisie pour le moment', style: TextStyle(color: AppTheme.textMuted)),
              ),
            )
          else
            ...vitalSigns.take(4).map((v) => _vitalSignCard(v)),
        ],
      ),
    );
  }

  // --- ONGLET 1 : Patients & Dossiers ---
  Widget _buildPatientsTab() {
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

    return Column(
      children: [
        // Barre de recherche
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Rechercher par nom, CIN, N° dossier...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (val) => setState(() => patientSearchQuery = val),
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
        const SizedBox(height: 8),

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

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 1,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _openPatientDossier(p),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
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
                                          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                          const SizedBox(height: 2),
                                          Text('CIN: $cin  |  Groupe: $blood', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: const Color(0xFFE0F2FE), borderRadius: BorderRadius.circular(4)),
                                      child: Text(dossier, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFF0284C7))),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                // Tags Service & Équipe pluridisciplinaire
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: dept.toString().contains('Matern') ? const Color(0xFFFDF2F8) : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(6),
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
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEFF6FF),
                                          borderRadius: BorderRadius.circular(6),
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
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFDF4FF),
                                          borderRadius: BorderRadius.circular(6),
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
    return ChoiceChip(
      showCheckmark: false,
      avatar: Icon(
        icon,
        size: 14,
        color: isSelected ? Colors.white : const Color(0xFF64748B),
      ),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : const Color(0xFF334155),
        ),
      ),
      selected: isSelected,
      selectedColor: const Color(0xFF0D9488),
      backgroundColor: const Color(0xFFF1F5F9),
      onSelected: (_) => setState(() => _selectedDepartmentFilter = value),
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
    return RefreshIndicator(
      onRefresh: _loadData,
      child: beds.isEmpty
          ? const Center(child: Text('Aucun lit répertorié'))
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.1,
              ),
              itemCount: beds.length,
              itemBuilder: (context, idx) {
                final b = beds[idx];
                final isOcc = b['isOccupied'] == true;
                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.bed,
                          size: 36,
                          color: isOcc ? Colors.red : Colors.green,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Lit ${b['bedNumber'] ?? b['number'] ?? idx + 1}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isOcc ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isOcc ? 'Occupé' : 'Disponible',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isOcc ? Colors.red[800] : Colors.green[800],
                            ),
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

  Widget _vitalSignCard(dynamic v) {
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
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        color: isAbnormal ? const Color(0xFFFFF1F2) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: isAbnormal ? const Color(0xFFFECDD3) : const Color(0xFFE2E8F0)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: patObj != null ? () => _openPatientDossier(patObj!) : null,
          child: Padding(
            padding: const EdgeInsets.all(14),
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

  Widget _badgeStat(String label, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white30),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
        ),
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
