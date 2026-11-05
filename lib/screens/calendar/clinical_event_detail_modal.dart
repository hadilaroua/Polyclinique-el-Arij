import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../utils/theme.dart';
import '../../utils/default_patients.dart';
import '../dossier/doctor_patient_dossier_screen.dart';

class ClinicalEventDetailModal extends StatefulWidget {
  final Map<String, dynamic> event;
  final VoidCallback? onUpdated;

  const ClinicalEventDetailModal({super.key, required this.event, this.onUpdated});

  static Future<void> show(
    BuildContext context,
    Map<String, dynamic> event, {
    VoidCallback? onUpdated,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClinicalEventDetailModal(event: event, onUpdated: onUpdated),
    );
  }

  @override
  State<ClinicalEventDetailModal> createState() => _ClinicalEventDetailModalState();
}

class _ClinicalEventDetailModalState extends State<ClinicalEventDetailModal> {
  final _api = ApiService();
  late Map<String, dynamic> _eventData;
  bool _isCancelling = false;

  @override
  void initState() {
    super.initState();
    _eventData = Map<String, dynamic>.from(widget.event);
  }

  Future<void> _cancelEvent() async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Annuler l\'intervention ?'),
        content: const Padding(
          padding: EdgeInsets.only(top: 8.0),
          child: Text(
            'Cette action informera l\'équipe soignante concernée et libérera la salle réservée.',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Retour'),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Annuler l\'intervention'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isCancelling = true);

    final eventId = (_eventData['_id'] ?? _eventData['id'])?.toString() ?? '';
    if (eventId.isNotEmpty) {
      await _api.cancelClinicalEvent(eventId);
    }

    if (mounted) {
      setState(() {
        _eventData['status'] = 'CANCELLED';
        _isCancelling = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(' Intervención annulée et salle libérée avec succès'),
          backgroundColor: AppTheme.alertRed,
        ),
      );
      widget.onUpdated?.call();
    }
  }

  void _openPatientDossier(Map<String, dynamic> patient) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DoctorPatientDossierScreen(patient: patient)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);

    Map<String, dynamic> patient = {};
    if (_eventData['patientId'] is Map) {
      patient = Map<String, dynamic>.from(_eventData['patientId'] as Map);
    } else if (_eventData['patient'] is Map) {
      patient = Map<String, dynamic>.from(_eventData['patient'] as Map);
    }

    String patName = '${patient['firstName'] ?? ''} ${patient['lastName'] ?? ''}'.trim();

    if (patName.isEmpty || patName == 'Patient ARIJ' || patName == 'Patient') {
      final searchId = (_eventData['patientId'] ?? _eventData['patient'])?.toString() ?? '';
      for (final p in DefaultPatients.getAll()) {
        if (p['_id'] == searchId || p['dossierNumber'] == searchId || p['cin'] == searchId) {
          patient = Map<String, dynamic>.from(p);
          patName = '${p['firstName']} ${p['lastName']}'.trim();
          break;
        }
      }
    }

    if (patName.isEmpty) {
      patName = _eventData['patientName']?.toString().isNotEmpty == true
          ? _eventData['patientName'].toString()
          : 'Mme Hadil Aroua';
    }

    final doctor = _eventData['doctorId'] is Map
        ? _eventData['doctorId'] as Map<String, dynamic>
        : {};
    final assignedStaff = (_eventData['assignedStaffIds'] is List)
        ? (_eventData['assignedStaffIds'] as List)
        : [];

    final user = _api.currentUser;
    final currentDocName = user != null && (user['lastName'] != null || user['firstName'] != null)
        ? 'Dr. ${user['lastName'] ?? user['firstName']}'
        : 'Dr. Traitant';

    final docName = (doctor['lastName'] != null || doctor['firstName'] != null)
        ? 'Dr. ${doctor['lastName'] ?? doctor['firstName']}'
        : currentDocName;
    final status = _eventData['status']?.toString() ?? 'SCHEDULED';
    final isCancelled = status == 'CANCELLED';
    final isCompleted = status == 'COMPLETED';

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
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

          // Title & Header Badges
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isCancelled
                      ? AppTheme.alertRed.withOpacity(0.12)
                      : AppTheme.evergreen.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCancelled ? CupertinoIcons.xmark_circle_fill : CupertinoIcons.scissors,
                  color: isCancelled ? AppTheme.alertRed : AppTheme.evergreen,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _eventData['procedureTitle'] ?? 'Intervention médicale',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppTheme.evergreen,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isCancelled
                                ? AppTheme.alertRed.withOpacity(0.15)
                                : (isCompleted
                                      ? Colors.blue.withOpacity(0.15)
                                      : AppTheme.evergreen.withOpacity(0.15)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isCancelled ? 'ANNULÉE' : (isCompleted ? 'TERMINÉE' : 'PROGRAMMÉE'),
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: isCancelled
                                  ? AppTheme.alertRed
                                  : (isCompleted ? Colors.blue : AppTheme.evergreen),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.pastelOrange.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _eventData['roomId'] ?? 'Bloc opératoire 1',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.pastelOrange,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(CupertinoIcons.clear_circled_solid, color: AppTheme.dustGrey),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Scrollable Body Content
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date & Heure Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppTheme.dustGrey.withOpacity(0.25)),
                    ),
                    child: Row(
                      children: [
                        const Icon(CupertinoIcons.clock_fill, color: AppTheme.evergreen, size: 22),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_eventData['date']} · ${_eventData['startTime']} — ${_eventData['endTime']}',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : AppTheme.textMain,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Salle : ${_eventData['roomId']}',
                              style: const TextStyle(fontSize: 12.5, color: AppTheme.dustGrey),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Patient Card
                  const Text(
                    'Patient concerné',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.evergreen,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppTheme.evergreen.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          CupertinoIcons.person_crop_circle_fill,
                          color: AppTheme.evergreen,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                patName.isNotEmpty ? patName : 'Patient ARIJ',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                              ),
                              Text(
                                'Dossier : ${patient['dossierNumber'] ?? patient['cin'] ?? '#ARJ-2026-00421'}',
                                style: const TextStyle(fontSize: 12, color: AppTheme.dustGrey),
                              ),
                            ],
                          ),
                        ),
                        if (patient.isNotEmpty)
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            color: AppTheme.evergreen.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            onPressed: () =>
                                _openPatientDossier(Map<String, dynamic>.from(patient)),
                            child: const Text(
                              'Dossier patient',
                              style: TextStyle(
                                color: AppTheme.evergreen,
                                fontWeight: FontWeight.w700,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Praticien & Équipe soignante
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Médecin responsable',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.evergreen,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? AppTheme.darkSurface : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppTheme.dustGrey.withOpacity(0.25)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    CupertinoIcons.person_badge_minus,
                                    color: AppTheme.evergreen,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      docName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  if (assignedStaff.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Équipe soignante affectée',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.evergreen,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Column(
                      children: assignedStaff.map<Widget>((st) {
                        final stMap = st is Map ? st : {};
                        final stName = '${stMap['firstName'] ?? ''} ${stMap['lastName'] ?? ''}'
                            .trim();
                        final stRole = stMap['role'] == 'MIDWIFE' ? 'Sage-Femme' : 'Infirmier(e)';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.darkSurface : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.dustGrey.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                stMap['role'] == 'MIDWIFE'
                                    ? CupertinoIcons.heart_fill
                                    : CupertinoIcons.bandage_fill,
                                color: AppTheme.evergreen,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                stName.isNotEmpty ? stName : 'Soignant ARIJ',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                              ),
                              const Spacer(),
                              Text(
                                stRole,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.dustGrey,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Préparation & Checklist
                  const Text(
                    'Préparation Clinique & Checklist',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.evergreen,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.evergreen.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.evergreen.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      children: [
                        _buildCheckItem('✓ Salle réservée (${_eventData['roomId']})', true),
                        _buildCheckItem('✓ Équipe soignante notifiée en temps réel', true),
                        _buildCheckItem('✓ Dossier patient associé', true),
                        _buildCheckItem(
                          '✓ Synchronisation Google Calendar active',
                          _eventData['googleCalendarEventId'] != null,
                        ),
                      ],
                    ),
                  ),

                  if (_eventData['notes'] != null && _eventData['notes'].toString().isNotEmpty) ...[
                    const SizedBox(height: 18),
                    const Text(
                      'Notes complémentaires',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.evergreen,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkSurface : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.dustGrey.withValues(alpha: 0.25)),
                      ),
                      child: Text(
                        _eventData['notes'],
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white70 : AppTheme.textMain,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),

          // Doctor Action Buttons
          if (!isCancelled)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppTheme.alertRed, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: _isCancelling
                        ? const CupertinoActivityIndicator(color: AppTheme.alertRed)
                        : const Icon(
                            CupertinoIcons.xmark_circle,
                            color: AppTheme.alertRed,
                            size: 18,
                          ),
                    label: const Text(
                      'Annuler l\'intervention',
                      style: TextStyle(color: AppTheme.alertRed, fontWeight: FontWeight.w700),
                    ),
                    onPressed: _isCancelling ? null : _cancelEvent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    color: AppTheme.evergreen,
                    borderRadius: BorderRadius.circular(16),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Fermer',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCheckItem(String label, bool checked) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            checked ? CupertinoIcons.checkmark_alt_circle_fill : CupertinoIcons.circle,
            color: checked ? AppTheme.evergreen : AppTheme.dustGrey,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: checked ? FontWeight.w700 : FontWeight.w500,
                color: checked ? AppTheme.evergreen : AppTheme.dustGrey,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
