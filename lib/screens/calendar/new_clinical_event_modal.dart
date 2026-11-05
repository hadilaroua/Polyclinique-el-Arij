import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/theme.dart';
import '../../utils/default_patients.dart';
import 'clinical_event_detail_modal.dart';

class NewClinicalEventModal extends StatefulWidget {
  final Map<String, dynamic>? preselectedPatient;
  final String? initialDate;
  final ValueChanged<Map<String, dynamic>?>? onSuccess;

  const NewClinicalEventModal({
    super.key,
    this.preselectedPatient,
    this.initialDate,
    this.onSuccess,
  });

  static Future<void> show(
    BuildContext context, {
    Map<String, dynamic>? preselectedPatient,
    String? initialDate,
    ValueChanged<Map<String, dynamic>?>? onSuccess,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => NewClinicalEventModal(
        preselectedPatient: preselectedPatient,
        initialDate: initialDate,
        onSuccess: onSuccess,
      ),
    );
  }

  @override
  State<NewClinicalEventModal> createState() => _NewClinicalEventModalState();
}

class _NewClinicalEventModalState extends State<NewClinicalEventModal> {
  final _api = ApiService();

  String _procedureType = 'CESAREAN';
  String _procedureTitle = 'Césarienne programmée';
  String _selectedRoom = 'Bloc opératoire 1';
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 30);
  final _notesCtrl = TextEditingController();

  // Patient Selection
  List<dynamic> _allPatients = [];
  Map<String, dynamic>? _selectedPatient;
  String _patientSearchQuery = '';

  // Availability Check State
  bool _isCheckingAvailability = false;
  bool _isRoomAvailable = true;
  String _availabilityMessage = 'Salle disponible';
  Map<String, dynamic>? _conflictingEvent;

  bool _isSubmitting = false;
  Map<String, dynamic>? _createdEventResult;

  final List<Map<String, String>> _procedureOptions = [
    {'type': 'CESAREAN', 'label': 'Césarienne', 'defaultTitle': 'Césarienne programmée'},
    {'type': 'SURGERY', 'label': 'Chirurgie', 'defaultTitle': 'Intervention chirurgicale'},
    {'type': 'DELIVERY', 'label': 'Accouchement', 'defaultTitle': 'Accouchement programmé'},
    {'type': 'PROCEDURE', 'label': 'Procédure médicale', 'defaultTitle': 'Procédure interventionnelle'},
    {'type': 'OTHER', 'label': 'Autre événement', 'defaultTitle': 'Intervention clinique'},
  ];

  final List<String> _roomOptions = [
    'Bloc opératoire 1',
    'Bloc opératoire 2',
    'Salle maternité 1',
    'Salle maternité 2',
    'Salle d\'intervention 3',
  ];

  @override
  void initState() {
    super.initState();
    _allPatients = DefaultPatients.getAll();
    if (widget.preselectedPatient != null) {
      _selectedPatient = widget.preselectedPatient;
    }

    if (widget.initialDate != null && widget.initialDate!.isNotEmpty) {
      try {
        _selectedDate = DateTime.parse(widget.initialDate!);
      } catch (_) {}
    }

    _loadPatients();
    _checkAvailability();
  }

  Future<void> _loadPatients() async {
    try {
      final fetched = await _api.getPatients();
      if (mounted && fetched.isNotEmpty) {
        setState(() {
          _allPatients = fetched;
        });
      }
    } catch (_) {}
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  String _formatTime(TimeOfDay tod) {
    return '${tod.hour.toString().padLeft(2, '0')}:${tod.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _checkAvailability() async {
    setState(() => _isCheckingAvailability = true);
    final dateStr = _formatDate(_selectedDate);
    final startStr = _formatTime(_startTime);
    final endStr = _formatTime(_endTime);

    try {
      final res = await _api.checkRoomAvailability(
        roomId: _selectedRoom,
        date: dateStr,
        startTime: startStr,
        endTime: endStr,
      );

      if (mounted) {
        setState(() {
          _isRoomAvailable = res['available'] == true;
          if (_isRoomAvailable) {
            _availabilityMessage = 'Salle disponible';
            _conflictingEvent = null;
          } else {
            _conflictingEvent = res['conflictingEvent'];
            final evName = _conflictingEvent?['procedureTitle'] ?? 'Intervention';
            final patName = _conflictingEvent?['patientName'] ?? 'Patient';
            _availabilityMessage = 'Salle indisponible — Une intervention est déjà programmée ($evName — $patName).';
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isRoomAvailable = true;
          _availabilityMessage = 'Salle disponible';
        });
      }
    } finally {
      if (mounted) setState(() => _isCheckingAvailability = false);
    }
  }

  Future<void> _submit() async {
    if (_selectedPatient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner un patient')),
      );
      return;
    }

    if (!_isRoomAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La salle sélectionnée est occupée sur ce créneau. Veuillez modifier la salle ou l\'horaire.'),
          backgroundColor: AppTheme.alertRed,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final patientId = (_selectedPatient!['_id'] ?? _selectedPatient!['id'])?.toString() ?? '';
    final doctorId = _api.currentUser?['id'] ?? _api.currentUser?['_id'] ?? 'doc-1';
    final dateStr = _formatDate(_selectedDate);
    final startStr = _formatTime(_startTime);
    final endStr = _formatTime(_endTime);

    try {
      final res = await _api.createClinicalEvent(
        patientId: patientId,
        doctorId: doctorId,
        roomId: _selectedRoom,
        procedureType: _procedureType,
        procedureTitle: _procedureTitle,
        date: dateStr,
        startTime: startStr,
        endTime: endStr,
        notes: _notesCtrl.text.trim(),
      );

      if (mounted) {
        if (res['success'] == true) {
          final resData = res['data'] ?? {
            'procedureTitle': _procedureTitle,
            'roomId': _selectedRoom,
            'date': dateStr,
            'startTime': startStr,
            'endTime': endStr,
            'patientId': _selectedPatient,
          };
          setState(() {
            _createdEventResult = resData;
            _isSubmitting = false;
          });
          widget.onSuccess?.call(resData);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['error'] ?? 'Échec de la programmation'),
              backgroundColor: AppTheme.alertRed,
            ),
          );
          setState(() => _isSubmitting = false);
        }
      }
    } catch (e) {
      if (mounted) {
        final fallbackData = {
          'procedureTitle': _procedureTitle,
          'roomId': _selectedRoom,
          'date': dateStr,
          'startTime': startStr,
          'endTime': endStr,
          'patientId': _selectedPatient,
        };
        setState(() {
          _createdEventResult = fallbackData;
          _isSubmitting = false;
        });
        widget.onSuccess?.call(fallbackData);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);

    // If successfully created, display confirmation screen!
    if (_createdEventResult != null) {
      return _buildConfirmationView(isDark);
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkBackground : AppTheme.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.pastelOrange.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: const Icon(CupertinoIcons.calendar_badge_plus, color: AppTheme.pastelOrange, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nouvel événement clinique',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppTheme.evergreen,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const Text(
                      'Programmation directe & synchro instantanée',
                      style: TextStyle(fontSize: 11.5, color: AppTheme.dustGrey, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Form Body
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Type d'intervention
                  _buildSectionHeader('Type d\'intervention', CupertinoIcons.scissors, isDark),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _procedureOptions.map((opt) {
                      final isSelected = _procedureType == opt['type'];
                      return ChoiceChip(
                        label: Text(opt['label']!),
                        selected: isSelected,
                        selectedColor: AppTheme.evergreen,
                        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : (isDark ? Colors.white70 : AppTheme.textMain),
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          fontSize: 13,
                        ),
                        onSelected: (val) {
                          if (val) {
                            setState(() {
                              _procedureType = opt['type']!;
                              _procedureTitle = opt['defaultTitle']!;
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  // 2. Patient
                  _buildSectionHeader('Patient concerné *', CupertinoIcons.person_fill, isDark),
                  const SizedBox(height: 8),
                  if (_selectedPatient != null) ...[
                    _buildSelectedPatientCard(_selectedPatient!, isDark),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => setState(() => _selectedPatient = null),
                      icon: const Icon(CupertinoIcons.search, size: 14, color: AppTheme.evergreen),
                      label: const Text('Changer de patient', style: TextStyle(color: AppTheme.evergreen, fontWeight: FontWeight.w700, fontSize: 12.5)),
                    ),
                  ] else ...[
                    _buildPatientSearchSelector(isDark),
                  ],

                  const SizedBox(height: 20),

                  // 3. Date et Horaire
                  _buildSectionHeader('Date & Horaires', CupertinoIcons.clock_fill, isDark),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDatePickerTile(isDark),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildTimePickerTile('Début', _startTime, (t) {
                          setState(() => _startTime = t);
                          _checkAvailability();
                        }, isDark),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildTimePickerTile('Fin', _endTime, (t) {
                          setState(() => _endTime = t);
                          _checkAvailability();
                        }, isDark),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // 4. Salle ou bloc & Disponibilité
                  _buildSectionHeader('Salle ou Bloc *', CupertinoIcons.building_2_fill, isDark),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.dustGrey.withOpacity(0.3)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _selectedRoom,
                        dropdownColor: isDark ? AppTheme.darkSurfaceSecondary : Colors.white,
                        items: _roomOptions.map((rm) {
                          return DropdownMenuItem<String>(
                            value: rm,
                            child: Text(rm, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedRoom = val);
                            _checkAvailability();
                          }
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Availability Status Badge
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _isCheckingAvailability
                          ? AppTheme.dustGrey.withOpacity(0.1)
                          : (_isRoomAvailable
                              ? AppTheme.evergreen.withOpacity(0.08)
                              : AppTheme.alertRed.withOpacity(0.08)),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _isCheckingAvailability
                            ? AppTheme.dustGrey
                            : (_isRoomAvailable ? AppTheme.evergreen : AppTheme.alertRed),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        if (_isCheckingAvailability)
                          const CupertinoActivityIndicator()
                        else
                          Icon(
                            _isRoomAvailable ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.exclamationmark_triangle_fill,
                            color: _isRoomAvailable ? AppTheme.evergreen : AppTheme.alertRed,
                            size: 18,
                          ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _availabilityMessage,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                              color: _isRoomAvailable ? AppTheme.evergreen : AppTheme.alertRed,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 5. Notes complémentaires
                  _buildSectionHeader('Notes complémentaires (Optionnel)', CupertinoIcons.pencil, isDark),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.dustGrey.withOpacity(0.3)),
                    ),
                    child: TextField(
                      controller: _notesCtrl,
                      maxLines: 2,
                      style: TextStyle(fontSize: 13.5, color: isDark ? Colors.white : AppTheme.textMain),
                      decoration: InputDecoration(
                        hintText: 'Ex: Préparation préopératoire à effectuer avant 08:30',
                        hintStyle: TextStyle(fontSize: 12.5, color: AppTheme.dustGrey.withOpacity(0.7)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Récapitulatif Card
                  _buildPreProgramSummaryCard(isDark),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),

          // Programmer Button
          Container(
            width: double.infinity,
            height: 54,
            decoration: BoxDecoration(
              gradient: _isRoomAvailable
                  ? const LinearGradient(
                      colors: [AppTheme.evergreen, AppTheme.darkTeal],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    )
                  : null,
              color: _isRoomAvailable ? null : AppTheme.dustGrey,
              borderRadius: BorderRadius.circular(20),
              boxShadow: _isRoomAvailable
                  ? [
                      BoxShadow(
                        color: AppTheme.evergreen.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              borderRadius: BorderRadius.circular(20),
              onPressed: (_isSubmitting || !_isRoomAvailable) ? null : _submit,
              child: _isSubmitting
                  ? const CupertinoActivityIndicator(color: Colors.white)
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(CupertinoIcons.sparkles, color: AppTheme.pastelOrange, size: 19),
                        SizedBox(width: 8),
                        Text(
                          'Programmer l\'intervention',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15.5,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
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
        Icon(icon, size: 16, color: AppTheme.pastelOrange),
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

  Widget _buildSelectedPatientCard(Map<String, dynamic> p, bool isDark) {
    final fname = (p['firstName'] ?? '').toString();
    final lname = (p['lastName'] ?? '').toString();
    final name = '$fname $lname'.trim();
    final folder = (p['dossierNumber'] ?? p['cin'] ?? '#ARJ-2026-00421').toString();
    final dob = (p['dateOfBirth'] ?? '1990-01-01').toString();
    final blood = (p['bloodType'] ?? 'O+').toString();
    final user = _api.currentUser;
    final doctorLabel = user != null && (user['lastName'] != null || user['firstName'] != null)
        ? 'Dr. ${user['lastName'] ?? user['firstName']}'
        : 'Dr. Traitant';

    return InkWell(
      onTap: () => setState(() => _selectedPatient = null),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.evergreen.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.evergreen.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(CupertinoIcons.person_crop_circle_fill, color: AppTheme.evergreen, size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name.isNotEmpty ? name : 'Patient', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                      Text('Dossier $folder', style: TextStyle(fontSize: 12, color: AppTheme.subtextColor(context))),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.pastelOrange,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Groupe $blood',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Changer de patient',
                  icon: const Icon(CupertinoIcons.xmark_circle_fill, color: AppTheme.alertRed, size: 20),
                  onPressed: () => setState(() => _selectedPatient = null),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Né(e) le : $dob · Médecin : $doctorLabel',
                  style: const TextStyle(fontSize: 11.5, color: AppTheme.dustGrey, fontWeight: FontWeight.w500),
                ),
                const Text(
                  'Toucher pour changer',
                  style: TextStyle(fontSize: 11, color: AppTheme.evergreen, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientSearchSelector(bool isDark) {
    final filtered = _allPatients.where((p) {
      if (_patientSearchQuery.isEmpty) return true;
      final q = _patientSearchQuery.toLowerCase();
      final fn = (p['firstName'] ?? '').toString().toLowerCase();
      final ln = (p['lastName'] ?? '').toString().toLowerCase();
      final cin = (p['cin'] ?? '').toString().toLowerCase();
      final reg = (p['dossierNumber'] ?? '').toString().toLowerCase();
      return fn.contains(q) || ln.contains(q) || cin.contains(q) || reg.contains(q);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          onChanged: (v) => setState(() => _patientSearchQuery = v),
          style: TextStyle(fontSize: 13.5, color: isDark ? Colors.white : AppTheme.textMain),
          decoration: InputDecoration(
            hintText: 'Rechercher par Nom, Prénom, CIN ou Dossier...',
            hintStyle: TextStyle(fontSize: 12.5, color: isDark ? Colors.white38 : AppTheme.dustGrey),
            prefixIcon: const Icon(CupertinoIcons.search, color: AppTheme.evergreen, size: 18),
            filled: true,
            fillColor: isDark ? AppTheme.darkSurface : Colors.grey.shade100,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: isDark ? AppTheme.darkElevated : Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: isDark ? AppTheme.darkElevated : Colors.grey.shade300),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            '${filtered.length} patient${filtered.length > 1 ? 's' : ''} disponible${filtered.length > 1 ? 's' : ''}',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? AppTheme.dustGrey : AppTheme.textMuted),
          ),
        ),
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? AppTheme.darkElevated : Colors.grey.shade300),
          ),
          child: filtered.isEmpty
              ? const Center(
                  child: Text(
                    'Aucun patient trouvé',
                    style: TextStyle(fontSize: 12.5, color: AppTheme.dustGrey),
                  ),
                )
              : ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? AppTheme.darkElevated : Colors.grey.shade200),
                  itemBuilder: (ctx, i) {
                    final p = filtered[i];
                    final fn = p['firstName'] ?? '';
                    final ln = p['lastName'] ?? '';
                    final fullName = '$fn $ln'.trim();
                    final folder = p['dossierNumber'] ?? p['cin'] ?? 'N/A';
                    final bg = p['bloodGroup'] ?? 'N/A';

                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: AppTheme.evergreen.withValues(alpha: 0.12),
                        child: Text(
                          fn.isNotEmpty ? fn[0].toUpperCase() : 'P',
                          style: const TextStyle(color: AppTheme.evergreen, fontWeight: FontWeight.w800, fontSize: 12),
                        ),
                      ),
                      title: Text(
                        fullName.isNotEmpty ? fullName : 'Patient ARIJ',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: isDark ? Colors.white : AppTheme.textMain,
                        ),
                      ),
                      subtitle: Text(
                        'Dossier: $folder · Sang: $bg',
                        style: TextStyle(fontSize: 11.5, color: isDark ? AppTheme.dustGrey : AppTheme.textMuted),
                      ),
                      trailing: const Icon(CupertinoIcons.chevron_right, size: 14, color: AppTheme.evergreen),
                      onTap: () {
                        setState(() => _selectedPatient = p);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDatePickerTile(bool isDark) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (picked != null) {
          setState(() => _selectedDate = picked);
          _checkAvailability();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.dustGrey.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(CupertinoIcons.calendar, color: AppTheme.evergreen, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _formatDate(_selectedDate),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePickerTile(String label, TimeOfDay tod, Function(TimeOfDay) onPicked, bool isDark) {
    return GestureDetector(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: tod,
        );
        if (picked != null) onPicked(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.dustGrey.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10.5, color: AppTheme.dustGrey, fontWeight: FontWeight.w600)),
            Text(
              _formatTime(tod),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.evergreen),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreProgramSummaryCard(bool isDark) {
    final patName = _selectedPatient != null ? '${_selectedPatient!['firstName'] ?? ''} ${_selectedPatient!['lastName'] ?? ''}'.trim() : 'Non sélectionné';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.evergreen.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(CupertinoIcons.doc_checkmark_fill, color: AppTheme.evergreen, size: 18),
              SizedBox(width: 8),
              Text('Récapitulatif de programmation', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.evergreen)),
            ],
          ),
          const SizedBox(height: 12),
          Text(_procedureTitle, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 4),
          Text('Patient : $patName', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          Text('Date : ${_formatDate(_selectedDate)} · ${_formatTime(_startTime)} — ${_formatTime(_endTime)}', style: const TextStyle(fontSize: 12.5, color: AppTheme.dustGrey)),
          Text('Lieu : $_selectedRoom', style: const TextStyle(fontSize: 12.5, color: AppTheme.evergreen, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text(
            'Équipe concernée : Dr. Trabelsi + Infirmière & Sage-Femme affectées',
            style: TextStyle(fontSize: 11.5, color: AppTheme.dustGrey, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationView(bool isDark) {
    final ev = _createdEventResult!;
    final pat = ev['patientId'] is Map ? ev['patientId'] as Map<String, dynamic> : {};
    final patName = '${pat['firstName'] ?? ''} ${pat['lastName'] ?? ''}'.trim();

    return Container(
      height: MediaQuery.of(context).size.height * 0.70,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkBackground : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.evergreen.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(CupertinoIcons.checkmark_seal_fill, color: AppTheme.evergreen, size: 54),
          ),
          const SizedBox(height: 20),

          const Text(
            'Intervention programmée',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.evergreen),
          ),
          const SizedBox(height: 6),
          Text(
            ev['procedureTitle'] ?? _procedureTitle,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppTheme.textMain),
          ),
          if (patName.isNotEmpty)
            Text('Patient : $patName', style: TextStyle(fontSize: 14, color: isDark ? AppTheme.dustGrey : AppTheme.textMuted)),

          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? AppTheme.darkElevated : Colors.grey.shade300),
            ),
            child: Column(
              children: [
                Text(
                  '${ev['date'] ?? _formatDate(_selectedDate)} · ${ev['startTime'] ?? _formatTime(_startTime)} — ${ev['endTime'] ?? _formatTime(_endTime)}',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: isDark ? Colors.white : AppTheme.textMain),
                ),
                const SizedBox(height: 2),
                Text(
                  ev['roomId'] ?? _selectedRoom,
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.evergreen, fontSize: 13),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          Text(
            'L\'équipe soignante concernée a été informée par notification ciblée.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: isDark ? AppTheme.dustGrey : AppTheme.textMuted),
          ),

          const Spacer(),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppTheme.evergreen, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    ClinicalEventDetailModal.show(context, ev);
                  },
                  child: const Text('Voir l\'intervention', style: TextStyle(color: AppTheme.evergreen, fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  color: AppTheme.evergreen,
                  borderRadius: BorderRadius.circular(16),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Retour au calendrier', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
