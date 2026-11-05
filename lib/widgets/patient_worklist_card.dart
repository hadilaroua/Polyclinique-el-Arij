import 'package:flutter/material.dart';

import '../utils/theme.dart';

class PatientWorklistCard extends StatelessWidget {
  final Map<String, dynamic> patient;
  final VoidCallback onTap;

  const PatientWorklistCard({super.key, required this.patient, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);
    final p = patient;
    final cin = p['cin'] ?? '-';
    final dossier = p['dossierNumber'] ?? 'PAT-000';
    final blood = p['bloodType'] ?? 'Inconnu';
    final dept = p['department'] ?? 'Médecine Générale';

    final rawName = '${p['firstName'] ?? ''} ${p['lastName'] ?? ''}'.trim();
    final prefix = p['gender'] == 'F' ? 'Mme.' : 'M.';
    final displayName = rawName.isEmpty
        ? 'Patient'
        : (rawName.startsWith('M.') || rawName.startsWith('Mme.') ? rawName : '$prefix $rawName');

    final allergiesRaw = p['allergies'];
    final allergies = allergiesRaw is List
        ? allergiesRaw.join(', ')
        : (allergiesRaw ?? '').toString();
    final hasAllergies =
        allergies.isNotEmpty &&
        allergies.toLowerCase() != 'aucune' &&
        allergies.toLowerCase() != 'aucune connue';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? AppTheme.darkElevated : AppTheme.dustGrey),
        boxShadow: [
          BoxShadow(
            color: AppTheme.evergreen.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar Stitch Style (comme Dossier 360)
                    Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEDF2EA),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${p['firstName']?.toString().isNotEmpty == true ? p['firstName'].toString()[0] : 'A'}${p['lastName']?.toString().isNotEmpty == true ? p['lastName'].toString()[0] : 'K'}'
                              .toUpperCase(),
                          style: const TextStyle(
                            color: AppTheme.evergreen,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
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
                              fontWeight: FontWeight.w800,
                              fontSize: 16.5,
                              color: isDark ? Colors.white : AppTheme.darkBackground,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: isDark ? AppTheme.darkElevated : const Color(0xFFEDF2EA),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'IPU #$dossier',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.evergreen,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${p['age'] ?? '48'} ans • Sexe ${p['gender'] == 'F' ? 'Féminin' : (p['gender'] == 'M' ? 'Masculin' : (p['gender'] ?? 'Masculin'))} • CIN: $cin',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.white70 : AppTheme.evergreen,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                                decoration: BoxDecoration(
                                  color: isDark ? AppTheme.darkElevated : const Color(0xFFEDF2EA),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 7,
                                      height: 7,
                                      decoration: const BoxDecoration(
                                        color: AppTheme.alertRed,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      'Groupe $blood',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white : AppTheme.darkBackground,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                                decoration: BoxDecoration(
                                  color: isDark ? AppTheme.darkElevated : const Color(0xFFEDF2EA),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Text(
                                  dept,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.evergreen,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Allergies format Stitch si présentes
                if (hasAllergies) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF351F20) : const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppTheme.alertRed.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.warning_rounded,
                            color: AppTheme.alertRed,
                            size: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Allergie : $allergies',
                            style: TextStyle(
                              color: isDark ? const Color(0xFFEF4444) : AppTheme.alertRed,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Divider(height: 1, color: isDark ? AppTheme.darkElevated : AppTheme.dustGrey),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF7A00).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Ouvrir le dossier',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFFF7A00),
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward_ios_rounded, size: 11, color: Color(0xFFFF7A00)),
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
    );
  }
}
