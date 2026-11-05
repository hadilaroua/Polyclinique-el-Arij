import 'package:flutter/material.dart';

import '../utils/theme.dart';

class PatientDossierHeader extends StatelessWidget {
  final Map<String, dynamic> patient;
  final String displayName;
  final String dossierNumber;
  final String bloodType;
  final String? stayLabel;
  final TabController tabController;
  final List<String> tabs;

  const PatientDossierHeader({
    super.key,
    required this.patient,
    required this.displayName,
    required this.dossierNumber,
    required this.bloodType,
    required this.stayLabel,
    required this.tabController,
    required this.tabs,
  });

  String get _initials {
    final firstName = patient['firstName']?.toString().trim() ?? '';
    final lastName = patient['lastName']?.toString().trim() ?? '';
    return '${firstName.isNotEmpty ? firstName[0] : 'P'}${lastName.isNotEmpty ? lastName[0] : 'A'}'
        .toUpperCase();
  }

  String? get _ageLabel {
    final birthDate = DateTime.tryParse(patient['dateOfBirth']?.toString() ?? '');
    if (birthDate != null) {
      final now = DateTime.now();
      var age = now.year - birthDate.year;
      if (now.month < birthDate.month ||
          (now.month == birthDate.month && now.day < birthDate.day)) {
        age--;
      }
      if (age >= 0) return '$age ans';
    }

    final existingAge = patient['age'];
    return existingAge is num ? '${existingAge.toInt()} ans' : null;
  }

  String? get _genderLabel {
    final gender = patient['gender']?.toString().trim().toUpperCase() ?? '';
    if (['F', 'FEMALE', 'FEMME', 'FÉMININ', 'FEMININ'].contains(gender)) return 'Féminin';
    if (['M', 'MALE', 'HOMME', 'MASCULIN'].contains(gender)) return 'Masculin';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);
    final accent = AppTheme.primaryColor(context);
    final rawAllergies = patient['allergies'];
    final allergies = rawAllergies is List
        ? rawAllergies
              .map((value) => value.toString().trim())
              .where((value) => value.isNotEmpty)
              .toList()
        : (rawAllergies?.toString().trim().isNotEmpty == true
              ? [rawAllergies.toString().trim()]
              : <String>[]);
    final demographics = [_ageLabel, _genderLabel].whereType<String>().join(' • ');

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : AppTheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.border),
            boxShadow: AppTheme.cardShadow(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: accent.withValues(alpha: 0.22)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _initials,
                      style: TextStyle(color: accent, fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.textMain,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (demographics.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            demographics,
                            style: TextStyle(fontSize: 12, color: AppTheme.subtextColor(context)),
                          ),
                        ],
                        const SizedBox(height: 5),
                        Wrap(
                          spacing: 7,
                          runSpacing: 5,
                          children: [
                            if (dossierNumber.trim().isNotEmpty)
                              _InfoPill(label: 'IPU #$dossierNumber'),
                            if (bloodType.trim().isNotEmpty && bloodType.toLowerCase() != 'inconnu')
                              _InfoPill(label: 'Groupe $bloodType', accent: AppTheme.pastelOrange),
                            if (stayLabel != null)
                              _InfoPill(label: stayLabel!, accent: AppTheme.fern),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (allergies.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.dangerColor(context).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.dangerColor(context).withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 17,
                        color: AppTheme.dangerColor(context),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          'Allergies : ${allergies.join(', ')}',
                          style: TextStyle(
                            color: AppTheme.dangerColor(context),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkElevated : AppTheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
          ),
          child: TabBar(
            controller: tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              color: isDark ? AppTheme.darkSurfaceActive : AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            labelColor: isDark ? AppTheme.darkPrimary : AppTheme.evergreen,
            unselectedLabelColor: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
            tabs: tabs.map((label) => Tab(text: label)).toList(),
          ),
        ),
      ],
    );
  }
}

class _InfoPill extends StatelessWidget {
  final String label;
  final Color? accent;

  const _InfoPill({required this.label, this.accent});

  @override
  Widget build(BuildContext context) {
    final color = accent ?? AppTheme.textMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
