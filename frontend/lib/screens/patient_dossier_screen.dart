import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../screens/staff_messenger_screen.dart';
import '../services/api_service.dart';
import '../utils/theme.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/theme_toggle_button.dart';

class PatientDossierScreen extends StatefulWidget {
  final Map<String, dynamic> patient;

  const PatientDossierScreen({super.key, required this.patient});

  @override
  State<PatientDossierScreen> createState() => _PatientDossierScreenState();
}

class _PatientDossierScreenState extends State<PatientDossierScreen> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabController;

  bool _loading = true;
  List<dynamic> _consultations = [];
  List<dynamic> _exams = [];
  List<dynamic> _vitalSigns = [];
  List<dynamic> _auditLogs = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadPatientData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPatientData() async {
    setState(() => _loading = true);
    final patientId = widget.patient['_id'];
    try {
      final results = await Future.wait([
        _api.getConsultations(patientId: patientId),
        _api.getExams(patientId: patientId),
        _api.getVitalSigns(patientId: patientId),
        _api.getAuditLogs(patientId: patientId),
      ]);

      if (mounted) {
        setState(() {
          _consultations = results[0];
          _exams = results[1];
          _vitalSigns = results[2];
          _auditLogs = results[3];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    try {
      final d = DateTime.parse(iso).toLocal();
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pat = widget.patient;
    final fullName = '${pat['firstName'] ?? ''} ${pat['lastName'] ?? ''}'.trim();
    final cin = pat['cin'] ?? 'N/A';
    final dossier = pat['dossierNumber'] ?? 'PAT-000';
    final bloodType = pat['bloodType'] ?? 'Inconnu';
    final allergies = pat['allergies'] ?? 'Aucune connue';
    final phone = pat['phone'] ?? '-';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.border),
              ),
              child: Image.asset(
                'assets/logo-polyclinique-arij.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.folder_shared, color: AppTheme.primary, size: 20),
              ),
            ),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                'Dossier Patient Numérique',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          const ThemeToggleButton(),
          IconButton(
            icon: const Icon(Icons.forum_outlined, color: AppTheme.primary),
            tooltip: 'Messagerie & Discuter du cas avec le staff',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StaffMessengerScreen(onLogout: () {}),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser le dossier',
            onPressed: _loadPatientData,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Fiche d'identité synthétique du patient
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0A000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AvatarWidget(
                            avatarUrl: pat['avatarUrl'],
                            name: fullName,
                            radius: 28,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        fullName,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE0F2FE),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        dossier,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0284C7),
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text('CIN: $cin', style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                                    const SizedBox(width: 12),
                                    Text('Tél: $phone', style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    _buildBadge('Groupe: $bloodType', const Color(0xFFF1F5F9), const Color(0xFF334155)),
                                    if (allergies.isNotEmpty && allergies.toLowerCase() != 'aucune')
                                      _buildBadge('⚠️ Allergie: $allergies', const Color(0xFFFEE2E2), const Color(0xFFDC2626)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Onglets cliniques
                Container(
                  color: Colors.white,
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    labelColor: AppTheme.primary,
                    unselectedLabelColor: const Color(0xFF64748B),
                    indicatorColor: AppTheme.primary,
                    indicatorWeight: 3,
                    tabs: [
                      Tab(icon: const Icon(Icons.medical_services_outlined, size: 20), text: 'Consultations (${_consultations.length})'),
                      Tab(icon: const Icon(Icons.biotech_outlined, size: 20), text: 'Examens (${_exams.length})'),
                      Tab(icon: const Icon(Icons.monitor_heart_outlined, size: 20), text: 'Constantes (${_vitalSigns.length})'),
                      Tab(icon: const Icon(Icons.history_edu_outlined, size: 20), text: 'Traçabilité (${_auditLogs.length})'),
                    ],
                  ),
                ),

                // Contenu des onglets
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildConsultationsTab(),
                      _buildExamsTab(),
                      _buildVitalSignsTab(),
                      _buildAuditLogsTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildBadge(String label, Color bg, Color text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: text)),
    );
  }

  // --- ONGLET 1 : Consultations ---
  Widget _buildConsultationsTab() {
    if (_consultations.isEmpty) {
      return _buildEmptyState('Aucune consultation enregistrée pour ce patient.');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _consultations.length,
      itemBuilder: (context, index) {
        final c = _consultations[index];
        final doctor = c['doctorId'];
        final doctorName = doctor != null ? 'Dr. ${doctor['firstName'] ?? ''} ${doctor['lastName'] ?? ''}'.trim() : 'Médecin';
        final items = (c['prescriptionItems'] as List<dynamic>?) ?? [];
        final attachments = (c['attachments'] as List<dynamic>?) ?? [];

        return Card(
          margin: const EdgeInsets.only(bottom: 14),
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
                      c['date'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      doctorName,
                      style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0284C7), fontSize: 13),
                    ),
                  ],
                ),
                const Divider(height: 20),
                Text('Motif : ${c['motive'] ?? '-'}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.assignment_turned_in, size: 18, color: Color(0xFF1D4ED8)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Diagnostic : ${c['diagnostic'] ?? '-'}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                        ),
                      ),
                    ],
                  ),
                ),
                if (c['clinicalExam'] != null && (c['clinicalExam'] as String).isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Examen clinique : ${c['clinicalExam']}', style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
                ],

                // Ordonnance structurée
                if (items.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('💊 Ordonnance Prescrite :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  Column(
                    children: items.map((item) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.medication, size: 16, color: Color(0xFF0284C7)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${item['medicine']} ${item['dosage'] ?? ''} — ${item['posology'] ?? ''} ${item['frequency'] ?? ''} pendant ${item['duration'] ?? ''}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ] else if (c['prescription'] != null && (c['prescription'] as String).isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text('Prescription : ${c['prescription']}', style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic)),
                ],

                // Pièces jointes / Ordonnance PDF
                if (attachments.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: attachments.map((att) {
                      return Chip(
                        avatar: const Icon(Icons.attach_file, size: 16, color: Color(0xFF0369A1)),
                        label: Text(att['name'] ?? 'Document joint', style: const TextStyle(fontSize: 12)),
                        backgroundColor: const Color(0xFFE0F2FE),
                      );
                    }).toList(),
                  ),
                ],

                if (c['followUpDate'] != null && (c['followUpDate'] as String).isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('📅 Prochain suivi prévu le : ${c['followUpDate']}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF059669), fontWeight: FontWeight.bold)),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddExamModal() {
    final typeCtrl = TextEditingController();
    final serviceCtrl = TextEditingController(text: 'Laboratoire');
    final notesCtrl = TextEditingController();
    final resultCtrl = TextEditingController();
    final docUrlCtrl = TextEditingController();
    String priority = 'MEDIUM';
    bool isAlreadyCompleted = false;

    final templates = {
      'Bio/NFS': 'Hb: 13.5 g/dL, Leucocytes: 7,200/mm3, Plaquettes: 260,000/mm3. Formule équilibrée.',
      'Biochimie': 'Ionogramme normal (Na+: 140 mmol/L, K+: 4.2 mmol/L). Glycémie à jeun: 5.4 mmol/L.',
      'Radio Thorax': 'Cliché de bonne qualité. Pas de foyer de condensation ni d\'épanchement pleural.',
      'Scanner Abdo': 'Pas d\'anomalie aiguë parenchymateuse. Organes abdominaux de taille et morphologie normales.',
      'PMA': 'Numération 45 M/mL, mobilité 40%, vitalité 80%. Bilan compatible protocole.',
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
                    const Icon(Icons.science, color: Color(0xFF0284C7), size: 24),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        '🔬 Saisie Directe Examen / Acte Technique',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Modèles fréquents :', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: templates.keys.map((key) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ActionChip(
                          avatar: const Icon(Icons.flash_on, size: 14, color: Color(0xFF0284C7)),
                          label: Text(key, style: const TextStyle(fontSize: 11)),
                          onPressed: () {
                            setModalState(() {
                              typeCtrl.text = key;
                              resultCtrl.text = templates[key] ?? '';
                              if (key.contains('Radio') || key.contains('Scan')) {
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
                    labelText: 'Type / Intitulé de l\'examen *',
                    hintText: 'Ex: Hémogramme complet, Radio Pulmonaire, Échographie',
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
                          labelText: 'Service / Plateau',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: priority,
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
                  title: const Text('Saisir le résultat immédiatement (Acte déjà réalisé)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  value: isAlreadyCompleted,
                  onChanged: (v) => setModalState(() => isAlreadyCompleted = v ?? false),
                ),
                if (isAlreadyCompleted) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: resultCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Résultats & Conclusions techniques *',
                      hintText: 'Saisir les résultats ou observations d\'analyse...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text('📎 Pièce jointe / Cliché / Compte-rendu PDF (Téléphone)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
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
                        '📷 Joindre une photo du résultat ou un PDF depuis le téléphone',
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
                ] else ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: notesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Indications ou consignes préliminaires',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.check_circle, color: Colors.white),
                    label: const Text('Enregistrer dans le Dossier', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    onPressed: () async {
                      if (typeCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez spécifier le type d\'examen')));
                        return;
                      }
                      Navigator.pop(ctx);
                      final currentUserId = _api.currentUser?['id'] ?? _api.currentUser?['_id'];
                      final patId = (widget.patient['_id'] ?? widget.patient['id'])?.toString() ?? '';
                      final res = await _api.createExam(
                        patientId: patId,
                        examType: typeCtrl.text.trim(),
                        service: serviceCtrl.text.trim(),
                        priority: priority,
                        requestNotes: notesCtrl.text.trim(),
                      );
                      if (res['success'] == true && isAlreadyCompleted) {
                        final createdId = res['data']?['_id']?.toString();
                        if (createdId != null) {
                          await _api.assignExam(createdId, currentUserId);
                          await _api.completeExam(
                            createdId,
                            resultCtrl.text.trim().isEmpty ? 'Examen réalisé sans anomalie.' : resultCtrl.text.trim(),
                            resultDocumentUrl: docUrlCtrl.text.trim(),
                          );
                        }
                      }
                      _loadPatientData();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: Color(0xFF059669),
                            content: Text('✅ Examen enregistré avec succès dans le dossier patient !'),
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

  void _showCompleteExamModal(Map<String, dynamic> exam) {
    final examId = exam['_id']?.toString() ?? '';
    final examTitle = exam['examType'] ?? 'Examen';
    final resultCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final docUrlCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
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
                  const Icon(Icons.biotech, color: Color(0xFF059669), size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('🔬 Saisie Résultat : $examTitle', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: resultCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Résultats & Conclusions techniques *',
                  hintText: 'Saisir les résultats d\'analyse ou compte-rendu...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Notes techniques internes (Appareils / Réactifs)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: docUrlCtrl,
                decoration: const InputDecoration(
                  labelText: '📎 URL Cliché / PDF Joint',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.check_circle, color: Colors.white),
                  label: const Text('Valider & Clôturer l\'Examen', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    if (resultCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez renseigner le résultat')));
                      return;
                    }
                    Navigator.pop(ctx);
                    await _api.completeExam(
                      examId,
                      resultCtrl.text.trim(),
                      notes: notesCtrl.text.trim(),
                      resultDocumentUrl: docUrlCtrl.text.trim(),
                    );
                    _loadPatientData();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: Color(0xFF059669),
                          content: Text('✅ Examen complété et validé !'),
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
    );
  }

  // --- ONGLET 2 : Examens ---
  Widget _buildExamsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Plateau Technique & Analyses', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            if (_api.currentUser?['role'] == 'DOCTOR' || _api.currentUser?['role'] == 'ADMIN' || _api.currentUser?['role'] == 'MIDWIFE') ...[
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                icon: const Icon(Icons.science_outlined, size: 16, color: Colors.white),
                label: const Text('+ Prescrire un Examen', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                onPressed: _showAddExamModal,
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        if (_exams.isEmpty)
          _buildEmptyState('Aucun examen prescrit ou réalisé pour ce patient.')
        else
          ..._exams.map((exam) {
            final status = exam['status'] ?? 'PENDING';
            final isCompleted = status == 'COMPLETED';
            final isInProgress = status == 'IN_PROGRESS';

            Color statusColor = const Color(0xFFD97706);
            Color statusBg = const Color(0xFFFEF3C7);
            String statusLabel = 'En attente';

            if (isCompleted) {
              statusColor = const Color(0xFF059669);
              statusBg = const Color(0xFFD1FAE5);
              statusLabel = 'Validé / Terminé';
            } else if (isInProgress) {
              statusColor = const Color(0xFF0284C7);
              statusBg = const Color(0xFFE0F2FE);
              statusLabel = 'En cours';
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 14),
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
                        Expanded(
                          child: Text(
                            exam['examType'] ?? 'Examen',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(6)),
                          child: Text(
                            statusLabel,
                            style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('Priorité : ${exam['priority'] ?? 'Normale'} | Service : ${exam['service'] ?? 'Général'}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    if (exam['requestNotes'] != null && (exam['requestNotes'] as String).isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text('Indication clinique : ${exam['requestNotes']}', style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic)),
                    ],
                    if (!isCompleted && _api.currentUser?['role'] == 'TECHNICIAN') ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                          icon: const Icon(Icons.edit_note, size: 16, color: Colors.white),
                          label: const Text('🔬 Saisir le Résultat', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          onPressed: () => _showCompleteExamModal(exam),
                        ),
                      ),
                    ],
                    if (isCompleted) ...[
                      const Divider(height: 20),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.check_circle, size: 16, color: Color(0xFF16A34A)),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Text('Résultat Technique Laboratoire / Radiologie :',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF166534))),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(exam['result'] ?? '', style: const TextStyle(fontSize: 13, color: Color(0xFF14532D))),
                            if (exam['technicalNotes'] != null && (exam['technicalNotes'] as String).isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text('Notes technicien : ${exam['technicalNotes']}',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF15803D), fontStyle: FontStyle.italic)),
                            ],
                            if (exam['resultDocumentUrl'] != null && (exam['resultDocumentUrl'] as String).isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Chip(
                                avatar: const Icon(Icons.picture_as_pdf, size: 16, color: Color(0xFF166534)),
                                label: const Text('Compte-rendu / Cliché joint', style: TextStyle(fontSize: 12)),
                                backgroundColor: const Color(0xFFDCFCE7),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  void _showAddVitalSignsModal() {
    final tempCtrl = TextEditingController(text: '37.0');
    final sysCtrl = TextEditingController(text: '120');
    final diaCtrl = TextEditingController(text: '80');
    final hrCtrl = TextEditingController(text: '75');
    final spo2Ctrl = TextEditingController(text: '98');
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
                Text(
                  '📊 Prise de Constantes — ${widget.patient['firstName']} ${widget.patient['lastName']}',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
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
                  decoration: const InputDecoration(labelText: 'Observations soignantes', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9488),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.pop(ctx);
                      final temp = double.tryParse(tempCtrl.text.trim());
                      final spo2 = int.tryParse(spo2Ctrl.text.trim());

                      final res = await _api.createVitalSign(
                        patientId: widget.patient['_id'],
                        temperature: temp,
                        bloodPressureSystolic: int.tryParse(sysCtrl.text.trim()),
                        bloodPressureDiastolic: int.tryParse(diaCtrl.text.trim()),
                        heartRate: int.tryParse(hrCtrl.text.trim()),
                        oxygenSaturation: spo2,
                        notes: notesCtrl.text.trim(),
                      );
                      await _loadPatientData();

                      if (mounted) {
                        if (res['success'] == true) {
                          messenger.showSnackBar(
                            const SnackBar(
                              backgroundColor: Color(0xFF0D9488),
                              content: Text('✅ Constantes enregistrées dans le dossier patient !'),
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
                    },
                    child: const Text('Enregistrer dans le dossier', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- ONGLET 3 : Constantes Vitales ---
  Widget _buildVitalSignsTab() {
    if (_vitalSigns.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.monitor_heart_outlined, size: 52, color: Color(0xFFCBD5E1)),
              const SizedBox(height: 12),
              const Text('Aucune constante vitale enregistrée pour ce patient.', style: TextStyle(color: Color(0xFF64748B))),
              if (_api.currentUser?['role'] == 'NURSE' || _api.currentUser?['role'] == 'MIDWIFE' || _api.currentUser?['role'] == 'ADMIN') ...[
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488)),
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text('Prendre les Constantes', style: TextStyle(color: Colors.white)),
                  onPressed: _showAddVitalSignsModal,
                ),
              ],
            ],
          ),
        ),
      );
    }
    final latest = _vitalSigns.first;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Relevés des Constantes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            if (_api.currentUser?['role'] == 'NURSE' || _api.currentUser?['role'] == 'MIDWIFE' || _api.currentUser?['role'] == 'ADMIN') ...[
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                label: const Text('+ Prendre Constantes', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                onPressed: _showAddVitalSignsModal,
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildVitalKpi('Température', '${latest['temperature'] ?? '-'} °C', Icons.thermostat, (latest['temperature'] ?? 37) >= 38.5)),
            const SizedBox(width: 8),
            Expanded(child: _buildVitalKpi('Pouls (FC)', '${latest['heartRate'] ?? '-'} bpm', Icons.favorite, (latest['heartRate'] ?? 75) > 110)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildVitalKpi(
                'Tension (TA)',
                '${latest['bloodPressureSystolic'] ?? '-'}/${latest['bloodPressureDiastolic'] ?? '-'}',
                Icons.speed,
                (latest['bloodPressureSystolic'] ?? 120) > 150,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: _buildVitalKpi('Oxygène (SpO2)', '${latest['oxygenSaturation'] ?? '-'} %', Icons.air, (latest['oxygenSaturation'] ?? 98) < 94)),
          ],
        ),
        const SizedBox(height: 20),
        const Text('Historique de Surveillance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 10),
        ..._vitalSigns.map((v) {
          final isFever = (v['temperature'] ?? 0) >= 38.5;
          final isHypox = (v['oxygenSaturation'] ?? 100) < 94;
          final isAbnormal = isFever || isHypox;

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            color: isAbnormal ? const Color(0xFFFFF1F2) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: isAbnormal ? const Color(0xFFFECDD3) : const Color(0xFFE2E8F0)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_formatDate(v['recordedAt']), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      if (isAbnormal)
                        const Text('🔴 Anomalie', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'T°: ${v['temperature'] ?? '-'}°C  |  FC: ${v['heartRate'] ?? '-'} bpm  |  TA: ${v['bloodPressureSystolic'] ?? '-'}/${v['bloodPressureDiastolic'] ?? '-'}  |  SpO2: ${v['oxygenSaturation'] ?? '-'}%',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isAbnormal ? const Color(0xFFBE123C) : const Color(0xFF334155)),
                  ),
                  if (v['notes'] != null && (v['notes'] as String).isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('Observation : ${v['notes']}', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xFF64748B))),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildVitalKpi(String label, String value, IconData icon, bool alert) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: alert ? const Color(0xFFFEE2E2) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: alert ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, color: alert ? Colors.red : AppTheme.primary, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: alert ? Colors.red[800] : const Color(0xFF64748B))),
                Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: alert ? Colors.red[900] : const Color(0xFF0F172A))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- ONGLET 4 : Traçabilité AuditLog ---
  Widget _buildAuditLogsTab() {
    if (_auditLogs.isEmpty) {
      return _buildEmptyState('Aucun acte clinique consigné dans le journal pour ce patient.');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _auditLogs.length,
      itemBuilder: (context, index) {
        final log = _auditLogs[index];
        final action = log['action'] ?? '';
        final actor = log['actorName'] ?? 'Soignant';
        final details = log['details'] ?? '';
        final date = _formatDate(log['createdAt']);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.verified, size: 20, color: Color(0xFF059669)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(actor, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                        Text(date, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(details, style: const TextStyle(fontSize: 13, color: Color(0xFF334155))),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
                      child: Text(action, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFF475569))),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.folder_open, size: 48, color: Color(0xFFCBD5E1)),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }
}
