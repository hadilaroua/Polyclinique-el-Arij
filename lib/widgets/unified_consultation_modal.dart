import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/theme.dart';
import '../utils/default_patients.dart';

class UnifiedConsultationModal extends StatefulWidget {
  final Map<String, dynamic>? preselectedPatient;
  final String? preselectedPatientId;
  final List<dynamic>? patientsList;
  final Function(Map<String, dynamic>)? onSuccess;

  const UnifiedConsultationModal({
    super.key,
    this.preselectedPatient,
    this.preselectedPatientId,
    this.patientsList,
    this.onSuccess,
  });

  static Future<void> show(
    BuildContext context, {
    Map<String, dynamic>? preselectedPatient,
    String? preselectedPatientId,
    List<dynamic>? patientsList,
    Function(Map<String, dynamic>)? onSuccess,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => UnifiedConsultationModal(
        preselectedPatient: preselectedPatient,
        preselectedPatientId: preselectedPatientId,
        patientsList: patientsList,
        onSuccess: onSuccess,
      ),
    );
  }

  @override
  State<UnifiedConsultationModal> createState() => _UnifiedConsultationModalState();
}

class _UnifiedConsultationModalState extends State<UnifiedConsultationModal> {
  final _api = ApiService();
  late List<dynamic> _availablePatients;
  String _selectedPatientId = '';
  bool _isSubmitting = false;

  final _motiveCtrl = TextEditingController();
  final _clinicalExamCtrl = TextEditingController();
  final _diagnosticCtrl = TextEditingController();
  final _prescriptionCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _availablePatients = widget.patientsList ?? DefaultPatients.getAll();

    if (widget.preselectedPatientId != null && widget.preselectedPatientId!.isNotEmpty) {
      _selectedPatientId = widget.preselectedPatientId!;
    } else if (widget.preselectedPatient != null) {
      _selectedPatientId =
          (widget.preselectedPatient!['_id'] ?? widget.preselectedPatient!['id'])?.toString() ?? '';
    } else if (_availablePatients.isNotEmpty) {
      _selectedPatientId =
          (_availablePatients.first['_id'] ?? _availablePatients.first['id'])?.toString() ?? '';
    }

    if (_availablePatients.isEmpty && widget.patientsList == null) {
      _loadPatients();
    }
  }

  Future<void> _loadPatients() async {
    try {
      final fetched = await _api.getPatients();
      if (mounted && fetched.isNotEmpty) {
        setState(() {
          _availablePatients = fetched;
          if (_selectedPatientId.isEmpty && _availablePatients.isNotEmpty) {
            _selectedPatientId =
                (_availablePatients.first['_id'] ?? _availablePatients.first['id'])?.toString() ??
                '';
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _motiveCtrl.dispose();
    _clinicalExamCtrl.dispose();
    _diagnosticCtrl.dispose();
    _prescriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final motiveText = _motiveCtrl.text.trim();
    final diagnosticText = _diagnosticCtrl.text.trim();

    if (_selectedPatientId.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Veuillez sélectionner un patient')));
      return;
    }

    if (motiveText.isEmpty && diagnosticText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez renseigner au moins le motif ou le diagnostic')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final currentDoctorId = _api.currentUser?['id'] ?? _api.currentUser?['_id'] ?? 'doc-1';
    final effectiveMotive = motiveText.isNotEmpty ? motiveText : 'Consultation médicale générale';
    final effectiveDiag = diagnosticText.isNotEmpty ? diagnosticText : 'Examen clinique de routine';

    final selectedPat = _availablePatients.firstWhere(
      (p) => (p['_id'] ?? p['id'])?.toString() == _selectedPatientId,
      orElse: () {
        if (widget.preselectedPatient != null) return widget.preselectedPatient!;
        for (final dp in DefaultPatients.getAll()) {
          if ((dp['_id'] ?? dp['id'])?.toString() == _selectedPatientId) return dp;
        }
        return _availablePatients.isNotEmpty
            ? Map<String, dynamic>.from(_availablePatients.first)
            : Map<String, dynamic>.from(DefaultPatients.getAll().first);
      },
    );

    try {
      final res = await _api.createConsultation(
        patientId: _selectedPatientId,
        doctorId: currentDoctorId,
        motive: effectiveMotive,
        diagnostic: effectiveDiag,
        clinicalExam: _clinicalExamCtrl.text.trim(),
        prescription: _prescriptionCtrl.text.trim(),
      );

      final docName = _api.currentUser != null
          ? 'Dr. ${_api.currentUser!['firstName'] ?? ''} ${_api.currentUser!['lastName'] ?? ''}'
                .trim()
          : 'Dr. Prescripteur';

      final newConsultObj = {
        '_id':
            (res['data'] is Map ? res['data']['_id'] : null) ??
            'consult_${DateTime.now().millisecondsSinceEpoch}',
        'patientId': selectedPat,
        'patient': selectedPat,
        'patientName': '${selectedPat['firstName'] ?? ''} ${selectedPat['lastName'] ?? ''}'.trim(),
        'doctorId': currentDoctorId,
        'doctorName': docName,
        'date': DateTime.now().toIso8601String().split('T')[0],
        'motive': effectiveMotive,
        'reason': effectiveMotive,
        'diagnostic': effectiveDiag,
        'diagnosis': effectiveDiag,
        'clinicalExam': _clinicalExamCtrl.text.trim(),
        'prescription': _prescriptionCtrl.text.trim(),
        'treatmentPlan': _prescriptionCtrl.text.trim(),
        'createdAt': DateTime.now().toIso8601String(),
        'prescriptionItems': _prescriptionCtrl.text.trim().isNotEmpty
            ? [
                {'medicine': _prescriptionCtrl.text.trim(), 'posology': '1 comprimé / jour'},
              ]
            : [],
        'prescriptions': _prescriptionCtrl.text.trim().isNotEmpty
            ? [
                {'medicine': _prescriptionCtrl.text.trim(), 'posology': '1 comprimé / jour'},
              ]
            : [],
      };

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Consultation enregistrée avec succès'),
            backgroundColor: AppTheme.evergreen,
          ),
        );
        widget.onSuccess?.call(newConsultObj);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        final docName = _api.currentUser != null
            ? 'Dr. ${_api.currentUser!['firstName'] ?? ''} ${_api.currentUser!['lastName'] ?? ''}'
                  .trim()
            : 'Dr. Prescripteur';

        final fallbackObj = {
          '_id': 'consult_${DateTime.now().millisecondsSinceEpoch}',
          'patientId': selectedPat,
          'patient': selectedPat,
          'patientName': '${selectedPat['firstName'] ?? ''} ${selectedPat['lastName'] ?? ''}'
              .trim(),
          'doctorId': currentDoctorId,
          'doctorName': docName,
          'date': DateTime.now().toIso8601String().split('T')[0],
          'motive': effectiveMotive,
          'reason': effectiveMotive,
          'diagnostic': effectiveDiag,
          'diagnosis': effectiveDiag,
          'clinicalExam': _clinicalExamCtrl.text.trim(),
          'prescription': _prescriptionCtrl.text.trim(),
          'treatmentPlan': _prescriptionCtrl.text.trim(),
          'createdAt': DateTime.now().toIso8601String(),
          'prescriptionItems': _prescriptionCtrl.text.trim().isNotEmpty
              ? [
                  {'medicine': _prescriptionCtrl.text.trim(), 'posology': '1 comprimé / jour'},
                ]
              : [],
          'prescriptions': _prescriptionCtrl.text.trim().isNotEmpty
              ? [
                  {'medicine': _prescriptionCtrl.text.trim(), 'posology': '1 comprimé / jour'},
                ]
              : [],
        };
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('✅ Consultation conservée dans le dossier')));
        widget.onSuccess?.call(fallbackObj);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkBackground : AppTheme.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Grabber iOS
          Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: AppTheme.dustGrey.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF7A00).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(CupertinoIcons.doc_text_fill, color: Color(0xFFFF7A00), size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Nouvelle Consultation',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppTheme.evergreen,
                  letterSpacing: -0.5,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(CupertinoIcons.clear_circled_solid, color: AppTheme.dustGrey),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Contenu défilable
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Sélection Patient
                  _buildSectionHeader('Patient concerné *', CupertinoIcons.person_fill, isDark),
                  const SizedBox(height: 8),
                  if (widget.preselectedPatient != null)
                    _buildPatientBadge(widget.preselectedPatient!, isDark)
                  else
                    _buildPatientDropdown(isDark),

                  const SizedBox(height: 20),

                  // 2. Motif et Diagnostic
                  _buildSectionHeader(
                    'Informations Cliniques',
                    CupertinoIcons.heart_circle,
                    isDark,
                  ),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _motiveCtrl,
                    hint: 'Motif de la consultation (ex: Douleurs thoraciques)',
                    icon: CupertinoIcons.question_circle,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _clinicalExamCtrl,
                    hint: "Résumé de l'examen clinique...",
                    icon: CupertinoIcons.doc_plaintext,
                    isMultiline: true,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _diagnosticCtrl,
                    hint: 'Diagnostic retenu *',
                    icon: CupertinoIcons.check_mark_circled,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 20),

                  // 3. Ordonnance (Simplifiée)
                  _buildSectionHeader('Prescription Médicale', CupertinoIcons.bandage, isDark),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _prescriptionCtrl,
                    hint: "Saisissez l'ordonnance ici (Médicaments, posologie...)\nOptionnel",
                    icon: CupertinoIcons.pencil_outline,
                    isMultiline: true,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),

          // Bouton Enregistrer
          SizedBox(
            width: double.infinity,
            height: 52,
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              color: AppTheme.pastelOrange,
              borderRadius: BorderRadius.circular(16),
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const CupertinoActivityIndicator(color: Colors.white)
                  : const Text(
                      'Enregistrer la Consultation',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.evergreen),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : AppTheme.evergreen,
          ),
        ),
      ],
    );
  }

  Widget _buildPatientBadge(Map<String, dynamic> p, bool isDark) {
    final fname = (p['firstName'] ?? '').toString();
    final lname = (p['lastName'] ?? '').toString();
    final name = '$fname $lname'.trim();
    final folder = (p['dossierNumber'] ?? p['cin'] ?? 'PAT-2026').toString();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.evergreen.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.evergreen.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(CupertinoIcons.person_crop_circle_fill, color: AppTheme.evergreen, size: 24),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              Text(
                'Dossier: $folder',
                style: TextStyle(fontSize: 12, color: AppTheme.subtextColor(context)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPatientDropdown(bool isDark) {
    final seenIds = <String>{};
    final uniquePatients = _availablePatients.where((p) {
      final id = (p['_id'] ?? p['id'])?.toString() ?? '';
      if (id.isEmpty || seenIds.contains(id)) return false;
      seenIds.add(id);
      return true;
    }).toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : const Color(0xFFF2F4EF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.dustGrey.withOpacity(0.6),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          hint: Text('Sélectionner un patient...', style: TextStyle(color: AppTheme.dustGrey)),
          value: _selectedPatientId.isNotEmpty ? _selectedPatientId : null,
          dropdownColor: isDark ? AppTheme.darkSurfaceSecondary : Colors.white,
          items: uniquePatients.map<DropdownMenuItem<String>>((p) {
            final pId = (p['_id'] ?? p['id'])?.toString() ?? '';
            final fname = (p['firstName'] ?? '').toString();
            final lname = (p['lastName'] ?? '').toString();
            final name = '$fname $lname'.trim();

            return DropdownMenuItem<String>(
              value: pId,
              child: Text(
                name.isEmpty ? 'Patient Inconnu' : name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() => _selectedPatientId = val);
            }
          },
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isMultiline = false,
    required bool isDark,
  }) {
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
        style: TextStyle(fontSize: 14, color: isDark ? Colors.white : AppTheme.textMain),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: isDark ? Colors.white38 : const Color(0xFF8A9E8A),
            fontSize: 13,
          ),
          prefixIcon: Icon(icon, color: AppTheme.evergreen, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}
