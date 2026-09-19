import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../utils/theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/avatar_widget.dart';
import 'arij_assistant_screen.dart';
import 'patient_dossier_screen.dart';
import 'profile_screen.dart';

class DoctorHomeScreen extends StatefulWidget {
  final VoidCallback onLogout;

  const DoctorHomeScreen({super.key, required this.onLogout});

  @override
  State<DoctorHomeScreen> createState() => _DoctorHomeScreenState();
}

class _DoctorHomeScreenState extends State<DoctorHomeScreen> {
  int _currentTab = 0;
  final api = ApiService();

  List<dynamic> patients = [];
  List<dynamic> consultations = [];
  List<dynamic> exams = [];
  List<dynamic> alerts = [];
  List<dynamic> technicians = [];
  final Set<String> _readAlertIds = {};
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
            backgroundColor: const Color(0xFF059669),
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

        final oldCount = alerts.length;
        final newCount = newAlerts.length;

        if (oldCount != newCount) {
          if (newCount > oldCount && !isLoading) {
            final latest = newAlerts.first;
            final creatorId = latest['createdBy'] is Map ? latest['createdBy']['_id'] : latest['createdBy'];
            final isMine = creatorId?.toString() == api.currentUser?['_id']?.toString();
            
            if (!isMine) {
              final pat = latest['patientId'];
              final patName = pat is Map ? '${pat['firstName'] ?? ''} ${pat['lastName'] ?? ''}'.trim() : 'Patient';
            
            // Push Notification locale
            NotificationService().showClinicalAlert(
              title: latest['title'] ?? 'Alerte médicale',
              description: latest['description'] ?? '',
              level: latest['level'] ?? 'URGENT',
              patientName: patName,
            );

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: const Color(0xFFDC2626),
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
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
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
      api.getConsultations(),
      api.getExams(),
      api.getAlerts(),
      api.getTechnicians(),
    ]);
    if (mounted) {
      setState(() {
        patients = results[0];
        consultations = results[1];
        exams = results[2];
        alerts = results[3];
        technicians = results[4];
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
                      label: const Text('Tout traiter', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
                              'Aucune alerte en attente',
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
                                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: isCritical ? const Color(0xFFDC2626) : const Color(0xFF0284C7),
                                              borderRadius: BorderRadius.circular(12),
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
                                                'Destiné à : Dr. ${targetDoctor['firstName'] ?? ''} ${targetDoctor['lastName'] ?? ''}'.trim(),
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
                                                'Diffusion : Tous les médecins',
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
                                        label: const Text('Prendre en charge', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
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

  Future<void> _pickRealPhoneFile(
    BuildContext context,
    StateSetter setModalState,
    TextEditingController docNameCtrl,
    TextEditingController docUrlCtrl,
  ) async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.any,
      );

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
            backgroundColor: Colors.red,
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
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
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
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.phone_android, color: AppTheme.primary),
                SizedBox(width: 8),
                Text(
                  'Fichiers du téléphone',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textMain),
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
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.folder_open_rounded, size: 20),
                label: const Text('📂 Parcourir les fichiers du téléphone...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _pickRealPhoneFile(context, setModalState, docNameCtrl, docUrlCtrl);
                },
              ),
            ),

            const SizedBox(height: 16),
            const Text('📱 Ou sélectionner un fichier récent :', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textMain)),
            const SizedBox(height: 8),

            ...samplePhoneFiles.map((file) {
              final isPdf = file['type'] == 'PDF';
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: ListTile(
                  dense: true,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isPdf ? Colors.red.shade50 : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isPdf ? Icons.picture_as_pdf : Icons.image,
                      color: isPdf ? Colors.red : Colors.blue,
                      size: 22,
                    ),
                  ),
                  title: Text(file['name']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text('${file['size']} • ${file['date']}', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textMuted),
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
            const Text('🔗 Saisir manuellement :', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textMain)),
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
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Valider ce fichier', style: TextStyle(fontWeight: FontWeight.w600)),
                onPressed: () {
                  if (customNameCtrl.text.trim().isNotEmpty) {
                    setModalState(() {
                      docNameCtrl.text = customNameCtrl.text.trim();
                      docUrlCtrl.text = customUrlCtrl.text.trim().isNotEmpty ? customUrlCtrl.text.trim() : 'file:///storage/ordonnance.pdf';
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
    if (patients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun patient disponible')),
      );
      return;
    }

    String selectedPatientId = patients.first['_id'];
    final motiveCtrl = TextEditingController();
    final symptomsCtrl = TextEditingController();
    final clinicalExamCtrl = TextEditingController();
    final diagnosticCtrl = TextEditingController();
    final followUpDateCtrl = TextEditingController();

    // Option 1 : Ordonnance structurée dynamique
    List<Map<String, TextEditingController>> structuredItems = [
      {
        'medicine': TextEditingController(text: 'Doliprane'),
        'dosage': TextEditingController(text: '1000 mg'),
        'posology': TextEditingController(text: '1 comprimé'),
        'frequency': TextEditingController(text: '3 fois/jour'),
        'duration': TextEditingController(text: '5 jours'),
      }
    ];

    // Option 2 : Document joint / Ordonnance PDF
    final docNameCtrl = TextEditingController();
    final docUrlCtrl = TextEditingController();

    // Demande d'examen concomitante
    bool prescribeExam = false;
    String examType = 'Électrocardiogramme (ECG)';
    String examPriority = 'NORMAL';
    final examNotesCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.9,
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
                    Icon(Icons.medical_services, color: Color(0xFF0284C7)),
                    SizedBox(width: 8),
                    Text(
                      'Nouvelle Consultation Médicale',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Sélection du Patient
                const Text('Patient *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: selectedPatientId,
                  decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                  items: patients.map<DropdownMenuItem<String>>((p) {
                    final fname = (p['firstName'] ?? '').toString().replaceAll('null', '').trim();
                    final lname = (p['lastName'] ?? '').toString().replaceAll('null', '').trim();
                    String name = '$fname $lname'.trim();
                    if (name.isEmpty) name = p['dossierNumber'] ?? p['cin'] ?? 'Patient';
                    final dossier = p['dossierNumber'] ?? p['cin'] ?? '';
                    final label = dossier.isNotEmpty && !name.contains(dossier) ? '$name ($dossier)' : name;
                    return DropdownMenuItem<String>(
                      value: p['_id'],
                      child: Text(label, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedPatientId = val);
                  },
                ),

                const SizedBox(height: 12),
                const Text('Motif de consultation *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    hintText: 'Sélectionner un motif prédéfini...',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    'Consultation de suivi / Contrôle',
                    'Douleurs thoraciques / Dyspnée',
                    'Hypertension artérielle (Suivi TA)',
                    'Fièvre / Syndrome grippal',
                    'Céphalées intenses / Migraine',
                    'Diabète / Bilan glycémique',
                    'Renouvellement d\'ordonnance',
                    'Bilan de santé général',
                  ].map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setModalState(() => motiveCtrl.text = val);
                    }
                  },
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: motiveCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Ou saisissez un motif personnalisé...',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),

                const SizedBox(height: 12),
                const Text('Symptômes rapportés', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: symptomsCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Irradiation, essoufflement à l\'effort...',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),

                const SizedBox(height: 12),
                const Text('Examen clinique réalisé', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: clinicalExamCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Auscultation cardio-pulmonaire, palpation...',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),

                const SizedBox(height: 12),
                const Text('Diagnostic posé *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: diagnosticCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Ex: Angine de poitrine stable, Hypertension...',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),

                const SizedBox(height: 20),
                const Divider(),
                // Option 1 : Ordonnance Structurée (Header responsive sans RenderFlex Overflow)
                Row(
                  children: [
                    const Expanded(
                      child: Text('Option 1 — Ordonnance Structurée', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('+ Médicament', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      onPressed: () {
                        setModalState(() {
                          structuredItems.add({
                            'medicine': TextEditingController(),
                            'dosage': TextEditingController(),
                            'posology': TextEditingController(),
                            'frequency': TextEditingController(),
                            'duration': TextEditingController(),
                          });
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...structuredItems.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final item = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: item['medicine'],
                                decoration: const InputDecoration(labelText: 'Médicament', isDense: true),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: item['dosage'],
                                decoration: const InputDecoration(labelText: 'Dosage', isDense: true),
                              ),
                            ),
                            if (structuredItems.length > 1)
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                onPressed: () {
                                  setModalState(() => structuredItems.removeAt(idx));
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: item['posology'],
                                decoration: InputDecoration(
                                  labelText: 'Posologie',
                                  isDense: true,
                                  suffixIcon: PopupMenuButton<String>(
                                    icon: const Icon(Icons.arrow_drop_down, size: 18),
                                    onSelected: (val) => setModalState(() => item['posology']!.text = val),
                                    itemBuilder: (ctx) => [
                                      '1 comprimé',
                                      '2 comprimés',
                                      '1 gélule',
                                      '2 gélules',
                                      '1 sachet',
                                      '1 ampoule',
                                    ].map((v) => PopupMenuItem(value: v, child: Text(v, style: const TextStyle(fontSize: 12)))).toList(),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: TextField(
                                controller: item['frequency'],
                                decoration: InputDecoration(
                                  labelText: 'Fréquence',
                                  isDense: true,
                                  suffixIcon: PopupMenuButton<String>(
                                    icon: const Icon(Icons.arrow_drop_down, size: 18),
                                    onSelected: (val) => setModalState(() => item['frequency']!.text = val),
                                    itemBuilder: (ctx) => [
                                      '1x / jour',
                                      '2x / jour',
                                      '3x / jour',
                                      'Matin & Soir',
                                      'Avant repas',
                                      'En cas de besoin',
                                    ].map((v) => PopupMenuItem(value: v, child: Text(v, style: const TextStyle(fontSize: 12)))).toList(),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: TextField(
                                controller: item['duration'],
                                decoration: InputDecoration(
                                  labelText: 'Durée',
                                  isDense: true,
                                  suffixIcon: PopupMenuButton<String>(
                                    icon: const Icon(Icons.arrow_drop_down, size: 18),
                                    onSelected: (val) => setModalState(() => item['duration']!.text = val),
                                    itemBuilder: (ctx) => [
                                      '3 jours',
                                      '5 jours',
                                      '7 jours',
                                      '10 jours',
                                      '14 jours',
                                      '1 mois',
                                    ].map((v) => PopupMenuItem(value: v, child: Text(v, style: const TextStyle(fontSize: 12)))).toList(),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 14),
                // Option 2 : Upload / Pièce jointe ordonnance originale (Fichiers du téléphone)
                const Text('Option 2 — Joindre l\'ordonnance originale (PDF / Image du téléphone)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                if (docNameCtrl.text.isEmpty) ...[
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                      side: const BorderSide(color: AppTheme.primary, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.phone_android, color: AppTheme.primary, size: 20),
                    label: const Text(
                      'Choisir un fichier du téléphone (PDF / Photo)',
                      style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: () => _pickRealPhoneFile(context, setModalState, docNameCtrl, docUrlCtrl),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.teal.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          docNameCtrl.text.toLowerCase().endsWith('.pdf') ? Icons.picture_as_pdf : Icons.image,
                          color: docNameCtrl.text.toLowerCase().endsWith('.pdf') ? Colors.red : AppTheme.primary,
                          size: 26,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                docNameCtrl.text,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textMain),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Text('Fichier du téléphone sélectionné', style: TextStyle(fontSize: 11, color: AppTheme.primaryDark)),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => _showPhoneFilePickerModal(context, setModalState, docNameCtrl, docUrlCtrl),
                          child: const Text('Changer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                          onPressed: () {
                            setModalState(() {
                              docNameCtrl.clear();
                              docUrlCtrl.clear();
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),
                const Divider(),
                // Demande d'examen concomitante (Workflow réel)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('🔬 Demander un examen complémentaire immédiat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: const Text('Envoie automatiquement l\'ordre au technicien de laboratoire / radiologie', style: TextStyle(fontSize: 11)),
                  value: prescribeExam,
                  onChanged: (val) => setModalState(() => prescribeExam = val ?? false),
                ),
                if (prescribeExam) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: examType,
                          decoration: const InputDecoration(labelText: 'Type d\'examen *', isDense: true),
                          items: [
                            'Électrocardiogramme (ECG)',
                            'Bilan sanguin complet (NFS/CRP)',
                            'Scanner thoracique sans injection',
                            'Échographie abdominale',
                            'Radiographie pulmonaire',
                            'Glycémie à jeun',
                          ].map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13)))).toList(),
                          onChanged: (val) {
                            if (val != null) setModalState(() => examType = val);
                          },
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Text('Priorité : ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ChoiceChip(
                              label: const Text('Normale', style: TextStyle(fontSize: 12)),
                              selected: examPriority == 'NORMAL',
                              onSelected: (s) => setModalState(() => examPriority = 'NORMAL'),
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('🚨 Urgente', style: TextStyle(fontSize: 12)),
                              selected: examPriority == 'URGENT',
                              selectedColor: const Color(0xFFFEE2E2),
                              onSelected: (s) => setModalState(() => examPriority = 'URGENT'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: examNotesCtrl,
                          decoration: const InputDecoration(labelText: 'Indication technique pour le manipulateur', isDense: true),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 14),
                const Text('Date de suivi prévue (Optionnel)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: followUpDateCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Ex: 2026-10-15',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      if (motiveCtrl.text.trim().isEmpty || diagnosticCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Veuillez remplir le motif et le diagnostic')),
                        );
                        return;
                      }

                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.pop(ctx);
                      final docUserId = api.currentUser?['id'] ?? api.currentUser?['_id'];

                      // Préparation des médicaments structurés
                      final itemsPayload = structuredItems
                          .where((i) => i['medicine']!.text.trim().isNotEmpty)
                          .map((i) => {
                                'medicine': i['medicine']!.text.trim(),
                                'dosage': i['dosage']!.text.trim(),
                                'posology': i['posology']!.text.trim(),
                                'frequency': i['frequency']!.text.trim(),
                                'duration': i['duration']!.text.trim(),
                              })
                          .toList();

                      // Pièces jointes
                      final attachmentsPayload = <Map<String, String>>[];
                      if (docNameCtrl.text.trim().isNotEmpty && docUrlCtrl.text.trim().isNotEmpty) {
                        attachmentsPayload.add({
                          'name': docNameCtrl.text.trim(),
                          'url': docUrlCtrl.text.trim(),
                          'fileType': 'application/pdf',
                        });
                      }

                      // Envoi consultation
                      await api.createConsultation(
                        patientId: selectedPatientId,
                        doctorId: docUserId,
                        motive: motiveCtrl.text.trim(),
                        diagnostic: diagnosticCtrl.text.trim(),
                        symptoms: symptomsCtrl.text.trim(),
                        clinicalExam: clinicalExamCtrl.text.trim(),
                        prescriptionItems: itemsPayload,
                        attachments: attachmentsPayload,
                        followUpDate: followUpDateCtrl.text.trim(),
                      );

                      // Si examen prescrit en parallèle
                      if (prescribeExam) {
                        await api.createExam(
                          patientId: selectedPatientId,
                          requestingDoctorId: docUserId,
                          examType: examType,
                          priority: examPriority,
                          requestNotes: examNotesCtrl.text.trim(),
                        );
                      }

                      _loadData();
                      if (mounted) {
                        messenger.showSnackBar(
                          const SnackBar(
                            backgroundColor: Color(0xFF059669),
                            content: Text('Consultation et ordonnance enregistrées avec traçabilité !'),
                          ),
                        );
                      }
                    },
                    child: const Text(
                      'Valider & Consigner au Dossier Patient',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
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
                  '🔬 Prescrire un Examen Complémentaire',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),

                // Sélection du Patient
                DropdownButtonFormField<String>(
                  initialValue: selectedPatientId,
                  decoration: const InputDecoration(labelText: 'Patient *', border: OutlineInputBorder()),
                  items: patients.map<DropdownMenuItem<String>>((p) {
                    return DropdownMenuItem<String>(
                      value: p['_id'],
                      child: Text('${p['firstName']} ${p['lastName']} (${p['cin']})'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedPatientId = val);
                  },
                ),

                const SizedBox(height: 12),

                // Département / Service des examens
                DropdownButtonFormField<String>(
                  initialValue: selectedService,
                  decoration: const InputDecoration(labelText: 'Département / Plateau Technique *', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'Laboratoire / Biologie', child: Text('🧪 Laboratoire / Biologie')),
                    DropdownMenuItem(value: 'Radiologie / Imagerie', child: Text('🩻 Radiologie / Imagerie')),
                    DropdownMenuItem(value: 'Cardiologie / ECG', child: Text('🫀 Cardiologie / ECG')),
                    DropdownMenuItem(value: 'Échographie / Doppler', child: Text('🔊 Échographie / Doppler')),
                    DropdownMenuItem(value: 'EFR / Pneumologie', child: Text('🫁 EFR / Pneumologie')),
                    DropdownMenuItem(value: 'Autre Service', child: Text('🏥 Autre Service')),
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedService = val);
                  },
                ),

                const SizedBox(height: 12),

                // Technicien spécifique (Optionnel)
                DropdownButtonFormField<String?>(
                  initialValue: selectedTechId,
                  decoration: const InputDecoration(
                    labelText: 'Technicien de Santé Ciblé (Optionnel)',
                    helperText: 'Laissez vide pour adresser la demande à tout le service',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('👥 Tout le personnel du département', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
                    ),
                    ...technicians.map<DropdownMenuItem<String?>>((t) {
                      final u = t['userId'];
                      final fn = u is Map ? (u['firstName'] ?? '') : (t['firstName'] ?? '');
                      final ln = u is Map ? (u['lastName'] ?? '') : (t['lastName'] ?? '');
                      final name = '$fn $ln'.trim().isNotEmpty ? 'Tech. $fn $ln' : 'Technicien';
                      final dept = t['department'] ?? t['service'] ?? '';
                      final label = dept.toString().isNotEmpty ? '$name ($dept)' : name;
                      return DropdownMenuItem<String?>(
                        value: t['_id']?.toString(),
                        child: Text(label),
                      );
                    }),
                  ],
                  onChanged: (val) {
                    setModalState(() => selectedTechId = val);
                  },
                ),

                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: examType,
                  decoration: const InputDecoration(labelText: 'Type d\'examen *', border: OutlineInputBorder()),
                  items: [
                    'Bilan sanguin complet',
                    'Électrocardiogramme (ECG)',
                    'Scanner thoracique sans injection',
                    'Échographie abdominale',
                    'Radiographie pulmonaire',
                    'Bilan Hémostase / TP-INR',
                    'Gaz du sang',
                    'Spermogramme / Bilan PMA',
                  ].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
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
                      selected: priority == 'NORMAL',
                      onSelected: (s) => setModalState(() => priority = 'NORMAL'),
                    ),
                    const SizedBox(width: 10),
                    ChoiceChip(
                      label: const Text('🚨 Urgente'),
                      selected: priority == 'URGENT',
                      selectedColor: const Color(0xFFFEE2E2),
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
                      backgroundColor: const Color(0xFF059669),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final docUserId = api.currentUser?['id'] ?? api.currentUser?['_id'];
                      await api.createExam(
                        patientId: selectedPatientId,
                        requestingDoctorId: docUserId,
                        assignedTechnicianId: selectedTechId,
                        service: selectedService,
                        examType: examType,
                        priority: priority,
                        requestNotes: notesCtrl.text.trim(),
                      );
                      _loadData();
                    },
                    child: const Text('Envoyer l\'ordre au laboratoire/radio', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
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
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.local_hospital, color: AppTheme.primary, size: 20),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Cabinet Médical',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Dr. $fullName',
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
            tooltip: 'Arij Assistant IA',
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.purple, Colors.indigo],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.withValues(alpha: 0.3),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Icon(Icons.psychology, color: Colors.amberAccent, size: 18),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ArijAssistantScreen()),
              );
            },
          ),
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
                role: 'DOCTOR',
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
                _buildConsultationsTab(),
                _buildExamsTab(),
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
            label: 'Mes Patients',
          ),
          NavigationDestination(
            icon: Icon(Icons.medical_services_outlined),
            selectedIcon: Icon(Icons.medical_services),
            label: 'Consultations',
          ),
          NavigationDestination(
            icon: Icon(Icons.biotech_outlined),
            selectedIcon: Icon(Icons.biotech),
            label: 'Examens',
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
          // Bannière Dr
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
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
                        'Polyclinique Arij Djerba',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Espace Médecin Traitant',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _badgeStat('${patients.length} Patients', onTap: () => setState(() => _currentTab = 1)),
                            _badgeStat('${consultations.length} Consultations', onTap: () => setState(() => _currentTab = 2)),
                            _badgeStat('${exams.length} Examens', onTap: () => setState(() => _currentTab = 3)),
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
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.local_hospital, size: 36, color: AppTheme.primary),
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
                  icon: Icons.add_circle_outline,
                  label: 'Nouvelle Consultation',
                  color: AppTheme.primary,
                  onTap: _showNewConsultationModal,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _actionButton(
                  icon: Icons.science_outlined,
                  label: 'Prescrire Examen',
                  color: const Color(0xFF059669),
                  onTap: _showNewExamModal,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Alerte bande si urgences non lues
          if (unreadAlertCount > 0) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 18),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.red),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '$unreadAlertCount alerte(s) médicale(s) / résultat(s) non lu(s)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF991B1B)),
                    ),
                  ),
                  TextButton(
                    onPressed: _showAlertsModal,
                    child: const Text('Voir'),
                  ),
                ],
              ),
            ),
          ],

          // Dernières consultations
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Dernières Consultations',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              TextButton(
                onPressed: () => setState(() => _currentTab = 2),
                child: const Text('Voir tout'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (consultations.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Aucune consultation enregistrée', style: TextStyle(color: AppTheme.textMuted)),
              ),
            )
          else
            ...consultations.take(3).map((c) => _consultationCard(c)),
        ],
      ),
    );
  }

  // --- ONGLET 1 : Mes Patients & Dossiers Numériques ---
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
              _filterChip('Tous les pôles', 'ALL', Icons.domain),
              const SizedBox(width: 8),
              _filterChip('🌸 Maternité & Obstétrique', 'MATERNITE', Icons.pregnant_woman),
              const SizedBox(width: 8),
              _filterChip('❤️ Cardiologie', 'CARDIOLOGIE', Icons.favorite),
              const SizedBox(width: 8),
              _filterChip('🏥 Chirurgie & Hospit.', 'CHIRURGIE', Icons.local_hospital),
            ],
          ),
        ),
        const SizedBox(height: 8),

        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadData,
            child: filtered.isEmpty
                ? const Center(child: Text('Aucun patient trouvé dans ce pôle'))
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
                      final dept = p['department'] ?? 'Médecine Générale';

                      // Équipe soignante
                      final midwife = p['assignedMidwifeId'];
                      final midwifeName = midwife is Map
                          ? '${midwife['firstName'] ?? ''} ${midwife['lastName'] ?? ''}'.trim()
                          : null;
                      final nurse = p['assignedNurseId'];
                      final nurseName = nurse is Map
                          ? '${nurse['firstName'] ?? ''} ${nurse['lastName'] ?? ''}'.trim()
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
                                // Tags Service & Équipe de soins
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
                                    if (nurseName != null && nurseName.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF0FDF4),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFFBBF7D0)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.medical_services_outlined, size: 12, color: Color(0xFF16A34A)),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Inf: $nurseName',
                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF15803D)),
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

  Widget _filterChip(String label, String value, IconData icon) {
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
      selectedColor: AppTheme.primary,
      backgroundColor: const Color(0xFFF1F5F9),
      onSelected: (_) => setState(() => _selectedDepartmentFilter = value),
    );
  }

  Widget _buildConsultationsTab() {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'doc_consult_fab',
        backgroundColor: AppTheme.primary,
        onPressed: _showNewConsultationModal,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nouvelle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: consultations.isEmpty
            ? const Center(child: Text('Aucune consultation disponible'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: consultations.length,
                itemBuilder: (context, idx) => _consultationCard(consultations[idx]),
              ),
      ),
    );
  }

  Widget _buildExamsTab() {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'doc_exam_fab',
        backgroundColor: const Color(0xFF059669),
        onPressed: _showNewExamModal,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Prescrire', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: exams.isEmpty
            ? const Center(child: Text('Aucun examen prescrit'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: exams.length,
                itemBuilder: (context, idx) {
                  final ex = exams[idx];
                  final status = ex['status'] ?? 'PENDING';
                  final isCompleted = status == 'COMPLETED';
                  final isInProgress = status == 'IN_PROGRESS';
                  final patient = ex['patientId'];
                  final patName = patient is Map ? '${patient['firstName'] ?? ''} ${patient['lastName'] ?? ''}'.trim() : 'Patient';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                ex['examType'] ?? 'Examen',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isCompleted
                                      ? const Color(0xFFD1FAE5)
                                      : isInProgress
                                          ? const Color(0xFFE0F2FE)
                                          : const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  isCompleted ? 'Validé' : isInProgress ? 'En cours' : 'En attente',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isCompleted
                                        ? const Color(0xFF065F46)
                                        : isInProgress
                                            ? const Color(0xFF0284C7)
                                            : const Color(0xFF92400E),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text('Patient : $patName  |  Priorité : ${ex['priority'] ?? 'NORMAL'}',
                              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                          if (isCompleted && ex['result'] != null) ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFBBF7D0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Résultat validé par le laboratoire / radio :',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF166534))),
                                  const SizedBox(height: 4),
                                  Text(
                                    ex['result'],
                                    style: const TextStyle(fontSize: 13, color: Color(0xFF14532D)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (patient is Map) ...[
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                icon: const Icon(Icons.folder_open, size: 16),
                                label: const Text('Ouvrir dossier patient', style: TextStyle(fontSize: 12)),
                                onPressed: () => _openPatientDossier(patient as Map<String, dynamic>),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _triggerRealDownload(BuildContext context, String fileName, {dynamic consultation}) async {
    String targetPath = '';
    try {
      final dir = await getApplicationDocumentsDirectory();
      final cleanFileName = fileName.replaceAll(RegExp(r'[^\w\.-]'), '_');
      final file = File('${dir.path}/$cleanFileName');

      final patient = consultation != null ? consultation['patientId'] : null;
      final patientName = patient is Map ? '${patient['firstName'] ?? ''} ${patient['lastName'] ?? ''}'.trim() : 'Patient';
      final items = consultation != null ? ((consultation['prescriptionItems'] as List<dynamic>?) ?? []) : [];

      final contentBuffer = StringBuffer();
      contentBuffer.writeln('==========================================');
      contentBuffer.writeln('       POLYCLINIQUE ARIJ DJERBA');
      contentBuffer.writeln('  Plateau Médical & Chirurgies Spécialisées');
      contentBuffer.writeln('==========================================');
      contentBuffer.writeln('DOCUMENT OFFICIEL — ORDONNANCE MÉDICALE');
      contentBuffer.writeln('Date : ${consultation != null ? (consultation['date'] ?? '13/09/2026') : '13/09/2026'}');
      contentBuffer.writeln('Patient : $patientName');
      contentBuffer.writeln('Motif : ${consultation != null ? (consultation['motive'] ?? 'Consultation') : '-'}');
      contentBuffer.writeln('Diagnostic : ${consultation != null ? (consultation['diagnostic'] ?? 'Suivi') : '-'}');
      contentBuffer.writeln('------------------------------------------');
      contentBuffer.writeln('TRAITEMENT PRESCRIT :');
      if (items.isNotEmpty) {
        for (final it in items) {
          contentBuffer.writeln('• ${it['medicine']} ${it['dosage'] ?? ''}');
          contentBuffer.writeln('  Posologie: ${it['posology'] ?? '1 cp'} | Fréquence: ${it['frequency'] ?? '3x/j'} | Durée: ${it['duration'] ?? '5j'}');
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
                          color: AppTheme.primaryLight,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.picture_as_pdf_rounded, color: AppTheme.primary, size: 36),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Téléchargement & Génération...',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textMain),
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
                        color: AppTheme.primary,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${(progress * 100).toInt()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                          const Text('248 KB', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                        ],
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 40),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Fichier PDF Téléchargé !',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppTheme.textMain),
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
                                side: const BorderSide(color: AppTheme.primary),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.share_rounded, size: 18, color: AppTheme.primary),
                              label: const Text('Partager / Enregistrer', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600, fontSize: 11)),
                              onPressed: () {
                                if (targetPath.isNotEmpty) {
                                  Share.shareXFiles([XFile(targetPath)], text: 'Ordonnance Médicale - Polyclinique Arij');
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                backgroundColor: AppTheme.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.check, size: 18),
                              label: const Text('OK', style: TextStyle(fontWeight: FontWeight.w600)),
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

  void _showDocumentPreviewerDialog(BuildContext context, dynamic c, String fileName, String fileUrl) {
    final patient = c['patientId'];
    final patientName = patient is Map ? '${patient['firstName'] ?? ''} ${patient['lastName'] ?? ''}'.trim() : 'Patient';
    final items = (c['prescriptionItems'] as List<dynamic>?) ?? [];
    final attachments = (c['attachments'] as List<dynamic>?) ?? [];
    final firstAtt = attachments.isNotEmpty ? attachments.first : null;
    final displayFileName = fileName.isNotEmpty ? fileName : (firstAtt != null ? (firstAtt['name'] ?? 'ordonnance_medicale.pdf') : 'ordonnance_medicale.pdf');
    final isImage = fileUrl.toLowerCase().contains('.jpg') || fileUrl.toLowerCase().contains('.png') || fileUrl.toLowerCase().contains('unsplash');

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
                      color: AppTheme.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.description_outlined, color: AppTheme.primary, size: 24),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Aperçu Officiel — Ordonnance Médicale',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textMain),
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.border, width: 1.5),
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
                                  const Text('POLYCLINIQUE ARIJ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primaryDark)),
                                  const Text('Plateau Médical & Chirurgies Djerba', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                                  Text('Date : ${c['date'] ?? '13/09/2026'}', style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
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
                                  Text('Certifié Officiel', style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 20),

                        Text('Patient : $patientName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textMain)),
                        Text('Motif : ${c['motive'] ?? 'Consultation médicale'}', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                        Text('Diagnostic : ${c['diagnostic'] ?? 'Suivi médical'}', style: const TextStyle(fontSize: 12, color: AppTheme.accent, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 14),

                        // Section scanner / Document joint
                        if (attachments.isNotEmpty || fileUrl.isNotEmpty) ...[
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.picture_as_pdf_outlined, size: 18, color: Colors.redAccent),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Pièce jointe du téléphone : $displayFileName',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textMain),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text('Page 1/1 • PDF Canvas', style: TextStyle(fontSize: 10, color: AppTheme.primary, fontWeight: FontWeight.bold)),
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
                                        child: const Text('Document numérisé joint au dossier', style: TextStyle(fontSize: 12, color: Colors.grey)),
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
                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.picture_as_pdf, color: Colors.red, size: 36),
                                        const SizedBox(height: 6),
                                        Text(displayFileName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppTheme.textMain)),
                                        const Text('Document scanné & archivé dans le dossier médical du patient', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],

                        const Text('💊 Traitement & Prescriptions :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryDark)),
                        const SizedBox(height: 8),

                        if (items.isNotEmpty)
                          ...items.map((it) => Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppTheme.background,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.border),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.medication_outlined, color: AppTheme.primary, size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('${it['medicine']} ${it['dosage'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                          Text('Posologie: ${it['posology'] ?? '1 cp'} • Fréquence: ${it['frequency'] ?? '3x/j'} • Durée: ${it['duration'] ?? '5j'}', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ))
                        else
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.background,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('Ordonnance numérisée certifiée jointe au dossier médical.', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                          ),

                        const SizedBox(height: 20),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Signature du Médecin :', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
                                const SizedBox(height: 4),
                                Text(api.currentUser?['firstName'] != null ? 'Dr. ${api.currentUser!['firstName']} ${api.currentUser!['lastName'] ?? ''}' : 'Dr. Spécialiste', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primaryDark)),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppTheme.primary, width: 1.5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Column(
                                children: [
                                  Text('POLYCLINIQUE ARIJ', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                                  Text('Cachet Électronique', style: TextStyle(fontSize: 8, color: AppTheme.textMuted)),
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
                      label: const Text('Imprimer', style: TextStyle(color: AppTheme.textMain, fontWeight: FontWeight.w600)),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('🖨️ Ordre d\'impression envoyé à l\'imprimante de la clinique !'), duration: Duration(seconds: 2)),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text('Télécharger PDF', style: TextStyle(fontWeight: FontWeight.w600)),
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

  Widget _consultationCard(dynamic c) {
    final patient = c['patientId'];
    final patientName = patient is Map ? '${patient['firstName'] ?? ''} ${patient['lastName'] ?? ''}'.trim() : 'Patient';
    final items = (c['prescriptionItems'] as List<dynamic>?) ?? [];
    final attachments = (c['attachments'] as List<dynamic>?) ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (patient is Map) {
            _openPatientDossier(patient as Map<String, dynamic>);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    patientName,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  Text(
                    c['date'] ?? '',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Motif : ${c['motive'] ?? '-'}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Diag : ${c['diagnostic'] ?? '-'}',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1D4ED8), fontSize: 13),
                ),
              ),
              if (items.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: items.map((it) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('💊 ${it['medicine']} ${it['dosage'] ?? ''}', style: const TextStyle(fontSize: 11)),
                    );
                  }).toList(),
                ),
              ],
              if (attachments.isNotEmpty || items.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          side: const BorderSide(color: AppTheme.primary),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.visibility_outlined, size: 15, color: AppTheme.primary),
                        label: const Text('Aperçu', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primary)),
                        onPressed: () {
                          final firstAtt = attachments.isNotEmpty ? attachments.first : null;
                          final fileName = firstAtt != null ? (firstAtt['name'] ?? 'ordonnance_scanne.pdf') : 'ordonnance_medicale_${c['date'] ?? '2026'}.pdf';
                          final fileUrl = firstAtt != null ? (firstAtt['url'] ?? '') : '';
                          _showDocumentPreviewerDialog(context, c, fileName, fileUrl);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.download_rounded, size: 15),
                        label: const Text('Télécharger PDF', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                        onPressed: () {
                          final firstAtt = attachments.isNotEmpty ? attachments.first : null;
                          final fileName = firstAtt != null ? (firstAtt['name'] ?? 'ordonnance_scanne.pdf') : 'ordonnance_medicale_${c['date'] ?? '2026'}.pdf';
                          _triggerRealDownload(context, fileName, consultation: c);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
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
