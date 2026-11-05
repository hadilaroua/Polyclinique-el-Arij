import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../screens/patient_dossier_screen.dart';
import '../utils/default_patients.dart';
import '../utils/theme.dart';

class ExamResultDetailModal extends StatelessWidget {
  final Map<String, dynamic> exam;
  final Map<String, dynamic>? patient;

  const ExamResultDetailModal({super.key, required this.exam, this.patient});

  static void show(
    BuildContext context, {
    required Map<String, dynamic> exam,
    Map<String, dynamic>? patient,
    List<dynamic>? globalPatientsList,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ExamResultDetailModal(
        exam: exam,
        patient:
            patient ?? resolvePatientMap(exam['patientId'] ?? exam['patient'], globalPatientsList),
      ),
    );
  }

  static Map<String, dynamic> resolvePatientMap(dynamic patientInput, List<dynamic>? patientsList) {
    if (patientInput == null) {
      if (patientsList != null && patientsList.isNotEmpty) {
        return Map<String, dynamic>.from(patientsList.first);
      }
      return Map<String, dynamic>.from(DefaultPatients.getAll().first);
    }

    if (patientInput is Map) {
      final raw = Map<String, dynamic>.from(patientInput);
      final fn = raw['firstName'] ?? (raw['userId'] is Map ? raw['userId']['firstName'] : null);
      final ln = raw['lastName'] ?? (raw['userId'] is Map ? raw['userId']['lastName'] : null);
      if (fn != null && fn.toString().trim().isNotEmpty) {
        return raw;
      }
      final pid = raw['patientId']?.toString() ?? raw['_id']?.toString() ?? raw['id']?.toString();
      if (pid != null && pid.isNotEmpty) {
        final match = _resolveById(pid, patientsList);
        if (match != null) return match;
      }
      if (raw['patientName'] != null && raw['patientName'].toString().isNotEmpty) {
        final matchName = _resolveByName(raw['patientName'].toString(), patientsList);
        if (matchName != null) return matchName;
        return {
          '_id': raw['_id'] ?? 'pat_custom',
          'firstName': raw['patientName'],
          'lastName': '',
          'dossierNumber': raw['dossierNumber'] ?? 'PAT-000',
        };
      }
      if (patientsList != null && patientsList.isNotEmpty) {
        return Map<String, dynamic>.from(patientsList.first);
      }
      return Map<String, dynamic>.from(DefaultPatients.getAll().first);
    }

    if (patientInput is String && patientInput.isNotEmpty) {
      final match = _resolveById(patientInput, patientsList);
      if (match != null) return match;

      final matchName = _resolveByName(patientInput, patientsList);
      if (matchName != null) return matchName;
    }

    if (patientsList != null && patientsList.isNotEmpty) {
      return Map<String, dynamic>.from(patientsList.first);
    }
    return Map<String, dynamic>.from(DefaultPatients.getAll().first);
  }

  static Map<String, dynamic>? _resolveById(String id, List<dynamic>? list) {
    if (list != null) {
      final matchLocal = list.cast<Map<String, dynamic>?>().firstWhere(
        (p) => p?['_id']?.toString() == id || p?['id']?.toString() == id,
        orElse: () => null,
      );
      if (matchLocal != null) return Map<String, dynamic>.from(matchLocal);
    }
    final defaults = DefaultPatients.getAll();
    final matchDefault = defaults.cast<Map<String, dynamic>?>().firstWhere(
      (p) => p?['_id']?.toString() == id || p?['id']?.toString() == id,
      orElse: () => null,
    );
    if (matchDefault != null) return Map<String, dynamic>.from(matchDefault);
    return null;
  }

  static Map<String, dynamic>? _resolveByName(String query, List<dynamic>? list) {
    final q = query.toLowerCase().trim();
    if (list != null) {
      for (final p in list) {
        final fn = (p['firstName'] ?? '').toString().toLowerCase();
        final ln = (p['lastName'] ?? '').toString().toLowerCase();
        final full = '$fn $ln';
        if (full.contains(q) || q.contains(fn) || q.contains(ln)) {
          return Map<String, dynamic>.from(p);
        }
      }
    }
    for (final p in DefaultPatients.getAll()) {
      final fn = (p['firstName'] ?? '').toString().toLowerCase();
      final ln = (p['lastName'] ?? '').toString().toLowerCase();
      final full = '$fn $ln';
      if (full.contains(q) || q.contains(fn) || q.contains(ln)) {
        return Map<String, dynamic>.from(p);
      }
    }
    return null;
  }

  String _formatDate(dynamic dateVal) {
    if (dateVal == null) return 'Date non spécifiée';
    final s = dateVal.toString();
    if (s.isEmpty) return 'Date non spécifiée';
    try {
      final dt = DateTime.parse(s).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} à ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return s;
    }
  }

  Future<void> _exportExamRecap(BuildContext context, Map<String, dynamic> patMap) async {
    final examType = exam['examType'] ?? 'Examen technique';
    final pfn = patMap['firstName'] ?? '';
    final pln = patMap['lastName'] ?? '';
    final patName = '$pfn $pln'.trim().isNotEmpty ? '$pfn $pln'.trim() : 'Patient';
    final patRegId = patMap['dossierNumber'] ?? patMap['registryId'] ?? 'PAT-000';
    final result = exam['result'] ?? 'Aucun résultat consigné.';
    final notes = exam['technicalNotes'] ?? 'N/A';
    final reqNotes = exam['requestNotes'] ?? 'N/A';
    final service = exam['service'] ?? 'Plateau Technique';

    try {
      final now = DateTime.now();
      final dateStr =
          '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} à ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      final content =
          '''============================================================
POLYCLINIQUE EL ARIJ - FICHE DÉTAILLÉE D'EXAMEN ET RÉSULTATS
RAPPORT ARCHIVÉ AU DOSSIER ÉLECTRONIQUE MÉDICAL
============================================================
Date de consultation : $dateStr
Service responsable   : $service
Acte / Type Examen   : $examType
Statut               : ${exam['status'] ?? 'VALIDÉ'}
Priorité             : ${exam['priority'] ?? 'NORMALE'}

DOSSIER PATIENT :
- Nom & Prénom       : $patName
- Numéro IPU         : $patRegId
- CIN                : ${patMap['cin'] ?? 'Non renseigné'}
- Groupe Sanguin     : ${patMap['bloodType'] ?? 'Non renseigné'}
- Allergies          : ${patMap['allergies'] ?? 'Aucune'}

PRESCRIPTION MÉDICALE :
- Motif & Indications : $reqNotes

RÉSULTATS BIOLOGIQUES & IMAGERIE :
$result

OBSERVATIONS ET NOTES TECHNIQUES :
$notes

============================================================
Document médical certifié conforme - Polyclinique El Arij
============================================================
''';

      final dir = await getApplicationDocumentsDirectory();
      final cleanName = patName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final fileName =
          'Resultat_${cleanName}_${examType.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}.txt';
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(content);

      if (context.mounted) {
        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'text/plain', name: fileName)],
          subject: 'Résultat d\'examen $examType - $patName',
          text: 'Fiche de résultat d\'examen pour $patName',
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppTheme.alertRed, content: Text('Erreur export: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);
    final patMap = patient ?? resolvePatientMap(exam['patientId'] ?? exam['patient'], null);

    final examType = exam['examType'] ?? exam['title'] ?? 'Examen médical';
    final service = exam['service'] ?? 'Plateau Technique';
    final status = exam['status'] ?? 'PENDING';
    final priority = exam['priority'] ?? 'MEDIUM';
    final isUrgent = priority == 'URGENT' || priority == 'HIGH';

    final pfn = patMap['firstName'] ?? '';
    final pln = patMap['lastName'] ?? '';
    final rawName = '$pfn $pln'.trim();
    final displayName = rawName.isEmpty ? 'Patient' : rawName;
    final dossier = patMap['dossierNumber'] ?? 'PAT-000';
    final cin = patMap['cin'] ?? '-';
    final age = patMap['age'] ?? '48';
    final gender = patMap['gender'] == 'F' ? 'Féminin' : 'Masculin';
    final blood = patMap['bloodType'] ?? 'A+';

    final doctorObj = exam['requestingDoctorId'] ?? (patMap['attendingDoctorId']);
    final docUser = doctorObj is Map
        ? (doctorObj['userId'] is Map ? doctorObj['userId'] : doctorObj['user'])
        : null;
    final dfn = docUser is Map
        ? (docUser['firstName'] ?? '')
        : (doctorObj is Map ? (doctorObj['firstName'] ?? '') : '');
    final dln = docUser is Map
        ? (docUser['lastName'] ?? '')
        : (doctorObj is Map ? (doctorObj['lastName'] ?? '') : '');
    final docName = '$dfn $dln'.trim().isNotEmpty ? 'Dr. $dfn $dln'.trim() : 'Dr. Prescripteur';

    final techObj = exam['assignedTechnicianId'];
    final techUser = techObj is Map
        ? (techObj['userId'] is Map ? techObj['userId'] : techObj['user'])
        : null;
    final tfn = techUser is Map
        ? (techUser['firstName'] ?? '')
        : (techObj is Map ? (techObj['firstName'] ?? '') : '');
    final tln = techUser is Map
        ? (techUser['lastName'] ?? '')
        : (techObj is Map ? (techObj['lastName'] ?? '') : '');
    final techName = '$tfn $tln'.trim().isNotEmpty ? 'Tech. $tfn $tln'.trim() : 'Plateau Technique';

    final reqNotes = exam['requestNotes'];
    final result = exam['result'];
    final techNotes = exam['technicalNotes'];
    final docUrl = exam['resultDocumentUrl'];
    final createdAt = exam['createdAt'];
    final updatedAt = exam['updatedAt'];

    Color statusBg = const Color(0xFFE0F2FE);
    Color statusColor = const Color(0xFF0369A1);
    String statusLabel = 'EN ATTENTE DE TRAITEMENT';
    IconData statusIcon = CupertinoIcons.clock_fill;

    if (status == 'IN_PROGRESS') {
      statusBg = const Color(0xFFE0F2FE);
      statusColor = const Color(0xFF0369A1);
      statusLabel = 'EN COURS DE RÉALISATION';
      statusIcon = CupertinoIcons.gear_alt_fill;
    } else if (status == 'COMPLETED' || status == 'DONE') {
      statusBg = const Color(0xFFD1FAE5);
      statusColor = const Color(0xFF047857);
      statusLabel = 'RÉSULTAT VALIDÉ & TRANSMIS';
      statusIcon = CupertinoIcons.checkmark_seal_fill;
    }

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
      decoration: AppTheme.bottomSheetDecoration(context),

      padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4.5,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white30 : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // En-tête principal de l'examen
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.evergreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    CupertinoIcons.doc_text_search,
                    color: AppTheme.evergreen,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        examType,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Service : $service',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.evergreen,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    CupertinoIcons.xmark_circle_fill,
                    color: isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF94A3B8),
                    size: 26,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Badge Statut & Urgence
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 12, color: statusColor),
                      const SizedBox(width: 5),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isUrgent)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.flame_fill, size: 12, color: Color(0xFFDC2626)),
                        SizedBox(width: 5),
                        Text(
                          'PRIORITÉ URGENTE',
                          style: TextStyle(
                            color: Color(0xFFDC2626),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Banner Fiche Patient Réelle
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCard : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF243245) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEDF2EA),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${pfn.isNotEmpty ? pfn[0] : 'P'}${pln.isNotEmpty ? pln[0] : 'T'}'
                            .toUpperCase(),
                        style: const TextStyle(
                          color: AppTheme.evergreen,
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
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
                          displayName,
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'IPU #$dossier • $age ans • $gender\nCIN: $cin • Groupe $blood',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? Colors.white70 : const Color(0xFF64748B),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => PatientDossierScreen(patient: patMap)),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.evergreen),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                    ),
                    child: const Text(
                      'Dossier patient',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.evergreen,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Section 1 : Demande & Motif Médecin
            _buildSectionHeader(
              context,
              icon: CupertinoIcons.doc_text,
              title: 'Prescription & Indications Cliniques',
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.borderColor(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Médecin Prescripteur :',
                        style: TextStyle(fontSize: 12, color: AppTheme.subtextColor(context)),
                      ),
                      Text(
                        docName,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.evergreen,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Date de Prescription :',
                        style: TextStyle(fontSize: 12, color: AppTheme.subtextColor(context)),
                      ),
                      Text(
                        _formatDate(createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textColor(context),
                        ),
                      ),
                    ],
                  ),
                  if (reqNotes != null && reqNotes.toString().trim().isNotEmpty) ...[
                    const Divider(height: 16),
                    Text(
                      'Renseignements Cliniques / Motif :',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textColor(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      reqNotes.toString(),
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.9)
                            : const Color(0xFF334155),
                        fontStyle: FontStyle.italic,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Section 2 : Résultats Validés de l'Examen
            _buildSectionHeader(
              context,
              icon: CupertinoIcons.checkmark_seal,
              title: 'Résultats & Compte-rendu Technique',
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: (status == 'COMPLETED' || status == 'DONE')
                    ? (isDark
                          ? const Color(0xFF064E3B).withValues(alpha: 0.3)
                          : const Color(0xFFECFDF5))
                    : (isDark ? AppTheme.darkSurface : Colors.white),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: (status == 'COMPLETED' || status == 'DONE')
                      ? (isDark ? const Color(0xFF047857) : const Color(0xFFA7F3D0))
                      : AppTheme.borderColor(context),
                  width: 1.2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        (status == 'COMPLETED' || status == 'DONE')
                            ? CupertinoIcons.checkmark_circle_fill
                            : CupertinoIcons.clock,
                        size: 16,
                        color: (status == 'COMPLETED' || status == 'DONE')
                            ? const Color(0xFF059669)
                            : AppTheme.pastelOrange,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Compte-rendu de l\'examen :',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: (status == 'COMPLETED' || status == 'DONE')
                                ? (isDark ? const Color(0xFF34D399) : const Color(0xFF065F46))
                                : AppTheme.textColor(context),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (updatedAt != null) ...[
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            _formatDate(updatedAt),
                            style: TextStyle(fontSize: 11, color: AppTheme.subtextColor(context)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    (result != null && result.toString().trim().isNotEmpty)
                        ? result.toString()
                        : 'L\'examen n\'a pas encore de résultat consigné par le technicien.',
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.4,
                      fontWeight: (result != null && result.toString().trim().isNotEmpty)
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: (result != null && result.toString().trim().isNotEmpty)
                          ? (isDark ? const Color(0xFFA7F3D0) : const Color(0xFF044E3B))
                          : AppTheme.subtextColor(context),
                    ),
                  ),

                  // Notes du technicien
                  if (techNotes != null && techNotes.toString().trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black26 : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                CupertinoIcons.gear_alt,
                                size: 13,
                                color: AppTheme.evergreen,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Notes techniques & Automate ($techName) :',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.evergreen,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            techNotes.toString(),
                            style: TextStyle(fontSize: 12, color: AppTheme.textColor(context)),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Document Joint / Pièce Jointe
                  if (docUrl != null && docUrl.toString().trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF0F766E).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(CupertinoIcons.paperclip, size: 16, color: Color(0xFF0F766E)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Document d\'examen joint :',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F766E),
                                  ),
                                ),
                                Text(
                                  docUrl.toString(),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0F766E),
                                    decoration: TextDecoration.underline,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Actions Export PDF / Partage
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.evergreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                icon: const Icon(CupertinoIcons.share, color: Colors.white, size: 18),
                label: const Text(
                  'Exporter / Partager le Compte-Rendu PDF',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                ),
                onPressed: () => _exportExamRecap(context, patMap),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required IconData icon,
    required String title,
  }) {
    final isDark = AppTheme.isDarkMode(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.evergreen),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF334155),
          ),
        ),
      ],
    );
  }
}
