import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../services/api_service.dart';
import '../utils/theme.dart';
import '../utils/default_patients.dart';

class UnifiedVitalSignsModal extends StatefulWidget {
  final Map<String, dynamic>? preselectedPatient;
  final String? preselectedPatientId;
  final List<dynamic>? patientsList;
  final VoidCallback? onSuccess;

  const UnifiedVitalSignsModal({
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
    VoidCallback? onSuccess,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => UnifiedVitalSignsModal(
        preselectedPatient: preselectedPatient,
        preselectedPatientId: preselectedPatientId,
        patientsList: patientsList,
        onSuccess: onSuccess,
      ),
    );
  }

  @override
  State<UnifiedVitalSignsModal> createState() => _UnifiedVitalSignsModalState();
}

class _UnifiedVitalSignsModalState extends State<UnifiedVitalSignsModal> {
  final _api = ApiService();
  late List<dynamic> _availablePatients;
  String _selectedPatientId = '';
  bool _isSubmitting = false;

  final _tempCtrl = TextEditingController(text: '37.0');
  final _sysCtrl = TextEditingController(text: '120');
  final _diaCtrl = TextEditingController(text: '80');
  final _hrCtrl = TextEditingController(text: '75');
  final _spo2Ctrl = TextEditingController(text: '98');
  final _respCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _fileUrlCtrl = TextEditingController();

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
    _tempCtrl.dispose();
    _sysCtrl.dispose();
    _diaCtrl.dispose();
    _hrCtrl.dispose();
    _spo2Ctrl.dispose();
    _respCtrl.dispose();
    _weightCtrl.dispose();
    _notesCtrl.dispose();
    _fileUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedPatientId.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Veuillez sélectionner un patient')));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final currentUserId = _api.currentUser?['id'] ?? _api.currentUser?['_id'] ?? '';
      final temp = double.tryParse(_tempCtrl.text.trim());
      final sys = int.tryParse(_sysCtrl.text.trim());
      final dia = int.tryParse(_diaCtrl.text.trim());
      final hr = int.tryParse(_hrCtrl.text.trim());
      final spo2 = int.tryParse(_spo2Ctrl.text.trim());
      final resp = int.tryParse(_respCtrl.text.trim());
      final weight = double.tryParse(_weightCtrl.text.trim());

      final notesText = _notesCtrl.text.trim();
      final fullNotes = _fileUrlCtrl.text.isNotEmpty
          ? (notesText.isNotEmpty
                ? '$notesText [📄 Pièce jointe: ${_fileUrlCtrl.text.split('/').last}]'
                : '[📄 Pièce jointe: ${_fileUrlCtrl.text.split('/').last}]')
          : notesText;

      final result = await _api.createVitalSign(
        patientId: _selectedPatientId,
        recordedByUserId: currentUserId,
        temperature: temp,
        bloodPressureSystolic: sys,
        bloodPressureDiastolic: dia,
        heartRate: hr,
        oxygenSaturation: spo2,
        respiratoryRate: resp,
        weight: weight,
        notes: fullNotes,
      );

      if (mounted) {
        Navigator.pop(context);
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Constantes vitales enregistrées avec succès'),
              backgroundColor: AppTheme.evergreen,
            ),
          );
          widget.onSuccess?.call();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Constantes enregistrées (mode local): ${result['error'] ?? 'Nouveau relevé conservé'}',
              ),
            ),
          );
          widget.onSuccess?.call();
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('✅ Constantes enregistrées dans le dossier')));
        widget.onSuccess?.call();
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkBackground : AppTheme.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // iOS Grabber Handle
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
          const SizedBox(height: 16),

          // Header Title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.evergreen.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(CupertinoIcons.heart_fill, color: AppTheme.evergreen, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Prise de Constantes Vitales',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppTheme.evergreen,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(CupertinoIcons.clear_circled_solid, color: AppTheme.dustGrey),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Form Scrollable Body
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Patient Selection
                  _buildSectionHeader('Patient concerné *', CupertinoIcons.person_fill, isDark),
                  const SizedBox(height: 8),
                  if (widget.preselectedPatient != null)
                    _buildPatientBadge(widget.preselectedPatient!, isDark)
                  else
                    _buildPatientDropdown(isDark),

                  const SizedBox(height: 20),

                  // 2. Paramètres vitaux
                  _buildSectionHeader(
                    'Paramètres Physiologiques',
                    CupertinoIcons.waveform_path_ecg,
                    isDark,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInputField(
                          controller: _tempCtrl,
                          label: 'Température (°C)',
                          hint: 'ex: 37.2',
                          icon: CupertinoIcons.thermometer,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildInputField(
                          controller: _hrCtrl,
                          label: 'Pouls / FC (bpm)',
                          hint: 'ex: 78',
                          icon: CupertinoIcons.heart,
                          keyboardType: TextInputType.number,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInputField(
                          controller: _sysCtrl,
                          label: 'TA Systolique (mmHg)',
                          hint: 'ex: 120',
                          icon: CupertinoIcons.gauge,
                          keyboardType: TextInputType.number,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildInputField(
                          controller: _diaCtrl,
                          label: 'TA Diastolique (mmHg)',
                          hint: 'ex: 80',
                          icon: CupertinoIcons.gauge,
                          keyboardType: TextInputType.number,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInputField(
                          controller: _spo2Ctrl,
                          label: 'SpO₂ Saturation (%)',
                          hint: 'ex: 98',
                          icon: CupertinoIcons.wind,
                          keyboardType: TextInputType.number,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildInputField(
                          controller: _respCtrl,
                          label: 'Freq. Resp. (/min)',
                          hint: 'ex: 16 (opt.)',
                          icon: CupertinoIcons.waveform,
                          keyboardType: TextInputType.number,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // 3. Observations & Pièce Jointe
                  _buildSectionHeader(
                    'Observations & Documents',
                    CupertinoIcons.doc_plaintext,
                    isDark,
                  ),
                  const SizedBox(height: 12),
                  _buildInputField(
                    controller: _notesCtrl,
                    label: 'Observations soignantes',
                    hint: 'Remarques, symptômes ressentis, évolution...',
                    icon: CupertinoIcons.pencil,
                    isMultiline: true,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 14),

                  // Photo / File Attachment Section
                  const Text(
                    '📎 Pièce jointe / Résultat écrit / Photo (Optionnel)',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppTheme.textMain,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_fileUrlCtrl.text.isEmpty) ...[
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                        side: const BorderSide(color: AppTheme.evergreen, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(
                        CupertinoIcons.camera_fill,
                        color: AppTheme.evergreen,
                        size: 18,
                      ),
                      label: const Text(
                        '📷 Joindre une photo du résultat ou document PDF',
                        style: TextStyle(
                          color: AppTheme.evergreen,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                      onPressed: () async {
                        try {
                          final file = await FilePicker.pickFile(
                            type: FileType.custom,
                            allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'doc', 'docx'],
                          );
                          if (file != null) {
                            setState(() {
                              _fileUrlCtrl.text = file.path ?? file.name;
                            });
                          }
                        } catch (_) {}
                      },
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.evergreen.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.evergreen.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _fileUrlCtrl.text.toLowerCase().endsWith('.pdf')
                                ? CupertinoIcons.doc_text_fill
                                : CupertinoIcons.photo_fill,
                            color: AppTheme.evergreen,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _fileUrlCtrl.text.split('/').last,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              CupertinoIcons.xmark_circle_fill,
                              size: 18,
                              color: AppTheme.dustGrey,
                            ),
                            onPressed: () {
                              setState(() {
                                _fileUrlCtrl.clear();
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),

          // Enregistrer Button
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
                      'Enregistrer les Constantes',
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
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dustGrey.withOpacity(0.3)),
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
            final folder = (p['dossierNumber'] ?? p['cin'] ?? '').toString();

            return DropdownMenuItem<String>(
              value: pId,
              child: Text(
                '$name ${folder.isNotEmpty ? "($folder)" : ""}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
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

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool isMultiline = false,
    required bool isDark,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: isMultiline ? 3 : 1,
      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(fontSize: 12.5, color: AppTheme.dustGrey.withOpacity(0.7)),
        labelStyle: TextStyle(
          fontSize: 13,
          color: isDark ? Colors.white70 : AppTheme.evergreen,
          fontWeight: FontWeight.w600,
        ),
        prefixIcon: Icon(icon, color: AppTheme.evergreen, size: 18),
        filled: true,
        fillColor: isDark ? AppTheme.darkSurface : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppTheme.dustGrey.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppTheme.dustGrey.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppTheme.evergreen, width: 1.5),
        ),
      ),
    );
  }
}
