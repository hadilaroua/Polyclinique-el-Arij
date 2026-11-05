import 'package:flutter/material.dart';

import '../utils/theme.dart';

enum PatientSummarySection { chronicDiseases, emergencyContact, careTeamNotes }

class PatientClinicalSummary extends StatelessWidget {
  final Map<String, dynamic> patient;
  final String title;
  final List<PatientSummarySection> sections;

  const PatientClinicalSummary({
    super.key,
    required this.patient,
    required this.title,
    required this.sections,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);
    final chronicDiseases = _listValue(patient['chronicDiseases']);
    final contact = patient['emergencyContact'];
    final contactDetails = contact is Map
        ? [
            contact['name'],
            contact['relation'],
            contact['phone'],
          ].where((value) => value != null && value.toString().trim().isNotEmpty).join(' • ')
        : '';
    final careTeamNotes = patient['careTeamNotes']?.toString().trim() ?? '';

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.border),
        boxShadow: AppTheme.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.textMain,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (sections.contains(PatientSummarySection.chronicDiseases))
            _SummaryRow(
              label: 'Antécédents chroniques',
              value: chronicDiseases.isEmpty
                  ? 'Aucun renseignement enregistré'
                  : chronicDiseases.join(', '),
            ),
          if (sections.contains(PatientSummarySection.emergencyContact))
            _SummaryRow(
              label: 'Contact d’urgence',
              value: contactDetails.isEmpty ? 'Non renseigné' : contactDetails,
            ),
          if (sections.contains(PatientSummarySection.careTeamNotes) && careTeamNotes.isNotEmpty)
            _SummaryRow(label: 'Transmission de l’équipe', value: careTeamNotes),
        ],
      ),
    );
  }

  List<String> _listValue(dynamic value) {
    if (value is List) {
      return value.map((item) => item.toString().trim()).where((item) => item.isNotEmpty).toList();
    }
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? [] : [text];
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isDark ? AppTheme.darkTextTertiary : AppTheme.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.textMain,
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class PatientPrescriptionList extends StatelessWidget {
  final List<dynamic> consultations;
  final String heading;
  final String emptyMessage;

  const PatientPrescriptionList({
    super.key,
    required this.consultations,
    required this.heading,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    final entries = _prescriptionEntries();
    final isDark = AppTheme.isDarkMode(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(heading, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(emptyMessage, style: const TextStyle(color: Colors.grey)),
              ),
            )
          else
            ...entries.map((entry) {
              final item = entry.item;
              final medicine = item['medicine']?.toString().trim() ?? '';
              final details =
                  [item['dosage'], item['posology'], item['frequency'], item['duration']]
                      .map((value) => value?.toString().trim() ?? '')
                      .where((value) => value.isNotEmpty)
                      .join(' • ');
              final instructions = item['instructions']?.toString().trim() ?? '';

              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface : AppTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      medicine.isEmpty ? 'Prescription' : medicine,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    if (details.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        details,
                        style: TextStyle(fontSize: 12.5, color: AppTheme.subtextColor(context)),
                      ),
                    ],
                    if (instructions.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        instructions,
                        style: TextStyle(fontSize: 12, color: AppTheme.subtextColor(context)),
                      ),
                    ],
                    if (item['medicine'] == null && medicine.isEmpty)
                      Text(
                        item['text']?.toString() ?? '',
                        style: const TextStyle(fontSize: 13, height: 1.4),
                      ),
                    if (entry.date.isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Text(
                        entry.date,
                        style: TextStyle(fontSize: 11, color: AppTheme.subtextColor(context)),
                      ),
                    ],
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  List<_PrescriptionEntry> _prescriptionEntries() {
    final entries = <_PrescriptionEntry>[];

    for (final consultation in consultations) {
      if (consultation is! Map) continue;
      final date = (consultation['date'] ?? consultation['createdAt'] ?? '').toString();
      final items = consultation['prescriptionItems'];
      var structuredCount = 0;

      if (items is List) {
        for (final item in items) {
          if (item is Map) {
            entries.add(_PrescriptionEntry(item: Map<String, dynamic>.from(item), date: date));
            structuredCount++;
          }
        }
      }

      final freeText = consultation['prescription']?.toString().trim() ?? '';
      if (structuredCount == 0 && freeText.isNotEmpty) {
        entries.add(_PrescriptionEntry(item: {'text': freeText}, date: date));
      }
    }

    return entries;
  }
}

class _PrescriptionEntry {
  final Map<String, dynamic> item;
  final String date;

  const _PrescriptionEntry({required this.item, required this.date});
}
